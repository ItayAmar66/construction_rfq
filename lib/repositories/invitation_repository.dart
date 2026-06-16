import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization_invitation.dart';
import '../models/enterprise/organization_type.dart';
import '../providers/providers.dart';
import '../repositories/audit_repository.dart';
import '../services/email_invite_service.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';
import '../models/account_status.dart';
import '../utils/role_invitation_policy.dart';
import '../utils/enterprise_role_labels.dart';
import '../utils/invitation_link_builder.dart';

class InvitationRepository {
  InvitationRepository({
    FirebaseFirestore? firestore,
    EmailInviteService? emailService,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _emailService = emailService ?? DevInviteDeliveryService(),
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final EmailInviteService _emailService;
  final AuditRepository _auditRepository;
  static const _uuid = Uuid();

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(AppConstants.invitationsCollection);

  bool get isEmailProviderConfigured => _emailService.isProductionConfigured;

  Stream<List<OrganizationInvitation>> watchInvitationsForOrg(String orgId) {
    if (orgId.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchInvitationsForOrg(orgId);
    }
    return _invites
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrganizationInvitation.fromMap(d.id, d.data()))
            .toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[InvitationRepo] watch org: $e');
      return <OrganizationInvitation>[];
    });
  }

  Future<OrganizationInvitation?> getInvitation(String inviteId) async {
    if (inviteId.isEmpty) return null;
    if (AppMode.isDemoMode) {
      return MockStore.instance.getInvitation(inviteId);
    }
    final snap = await _invites.doc(inviteId).get();
    if (!snap.exists || snap.data() == null) return null;
    return OrganizationInvitation.fromMap(snap.id, snap.data()!);
  }

  Stream<List<OrganizationInvitation>> watchPendingForEmail(String email) {
    if (email.isEmpty) return Stream.value(const []);
    if (AppMode.isDemoMode) {
      return MockStore.instance.watchPendingInvitationsForEmail(email);
    }
    return _invites
        .where('email', isEqualTo: email.trim().toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OrganizationInvitation.fromMap(d.id, d.data()))
            .toList())
        .handleError((e) {
      if (kDebugMode) debugPrint('[InvitationRepo] watch email: $e');
      return <OrganizationInvitation>[];
    });
  }

  Future<OrganizationInvitation> createInvitation({
    required String orgId,
    required OrganizationType orgType,
    required String email,
    required EnterpriseRole role,
    required String invitedByUid,
    String? invitedByName,
    String? invitedByEmail,
    String? displayName,
    required bool canManage,
    List<EnterpriseRole> actorRoles = const [],
    String? companyLabel,
  }) async {
    _validateCreate(
      orgType: orgType,
      role: role,
      email: email,
      canManage: canManage,
      actorRoles: actorRoles,
    );
    final normalizedEmail = email.trim().toLowerCase();
    final now = DateTime.now();
    final invite = OrganizationInvitation(
      id: _uuid.v4(),
      orgId: orgId,
      orgType: orgType,
      email: normalizedEmail,
      displayName:
          displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      role: role,
      status: 'pending',
      deliveryStatus: InviteDeliveryStatus.pending,
      invitedByUid: invitedByUid,
      invitedByName: invitedByName,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
    );
    OrganizationInvitation saved;
    if (AppMode.isDemoMode) {
      saved = MockStore.instance.createInvitation(invite);
    } else {
      await _invites.doc(invite.id).set({
        ...invite.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(invite.expiresAt!),
      });
      saved = invite;
    }

    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: invitedByUid,
      actorEmail: invitedByEmail,
      actorName: invitedByName,
      orgId: orgId,
      orgType: orgType,
      entityType: AuditEntityType.invitation,
      entityId: saved.id,
      action: AuditAction.invitationCreated,
      summaryHebrew:
          'נוצרה הזמנה ל-${EnterpriseRoleLabels.hebrew(role)} עבור $normalizedEmail',
      metadata: {'email': normalizedEmail, 'role': role.value},
    );

    return saved;
  }

  Future<InviteDeliveryResult> deliverInvitation({
    required OrganizationInvitation invitation,
    String? companyLabel,
    required bool canManage,
  }) async {
    if (!canManage) throw Exception('אין הרשאה לשלוח הזמנה');
    final result = await _emailService.sendInvitationEmail(
      invitation,
      companyLabel: companyLabel ?? invitation.orgId,
    );
    await _updateDeliveryStatus(invitation.id, result.status);
    return result;
  }

  Future<void> cancelInvitation({
    required String inviteId,
    required bool canManage,
    required String actorUid,
    String? actorEmail,
    String? actorName,
    OrganizationInvitation? inviteForAudit,
  }) async {
    if (!canManage) {
      throw Exception('אין הרשאה לבטל הזמנה');
    }
    if (AppMode.isDemoMode) {
      MockStore.instance.cancelInvitation(inviteId);
    } else {
      await _invites.doc(inviteId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final invite = inviteForAudit ?? await getInvitation(inviteId);
    if (invite != null) {
      await AuditLogger.record(
        repository: _auditRepository,
        actorUid: actorUid,
        actorEmail: actorEmail,
        actorName: actorName,
        orgId: invite.orgId,
        orgType: invite.orgType,
        entityType: AuditEntityType.invitation,
        entityId: inviteId,
        action: AuditAction.invitationCancelled,
        summaryHebrew: 'הזמנה בוטלה עבור ${invite.email}',
      );
    }
  }

  Future<Membership> acceptInvitation({
    required String inviteId,
    required String uid,
    required String email,
    String? actorName,
  }) async {
    if (AppMode.isDemoMode) {
      final membership = MockStore.instance.acceptInvitation(
        inviteId: inviteId,
        uid: uid,
        email: email,
      );
      final invite = MockStore.instance.getInvitation(inviteId);
      if (invite != null) {
        await AuditLogger.record(
          repository: _auditRepository,
          actorUid: uid,
          actorEmail: email,
          actorName: actorName,
          orgId: invite.orgId,
          orgType: invite.orgType,
          entityType: AuditEntityType.invitation,
          entityId: inviteId,
          action: AuditAction.invitationAccepted,
          summaryHebrew:
              'הצטרפות לחברה בתפקיד ${EnterpriseRoleLabels.hebrew(invite.role)}',
        );
      }
      return membership;
    }
    final inviteRef = _invites.doc(inviteId);
    final inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists || inviteSnap.data() == null) {
      throw Exception('ההזמנה לא נמצאה');
    }
    final invite =
        OrganizationInvitation.fromMap(inviteSnap.id, inviteSnap.data()!);
    _validateAccept(invite: invite, uid: uid, email: email);

    final memberRef = _db
        .collection(AppConstants.organizationsCollection)
        .doc(invite.orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(uid);

    await memberRef.set({
      'uid': uid,
      'orgId': invite.orgId,
      'orgType': invite.orgType.value,
      'roles': [invite.role.value],
      'status': 'active',
      'email': email.trim().toLowerCase(),
      if (actorName != null && actorName.trim().isNotEmpty)
        'displayName': actorName.trim(),
      'acceptedInvitationId': inviteId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'accountStatus': AccountStatus.active.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await inviteRef.update({
      'status': 'accepted',
      'deliveryStatus': InviteDeliveryStatus.accepted,
      'acceptedByUid': uid,
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogger.record(
      repository: _auditRepository,
      actorUid: uid,
      actorEmail: email,
      actorName: actorName,
      orgId: invite.orgId,
      orgType: invite.orgType,
      entityType: AuditEntityType.invitation,
      entityId: inviteId,
      action: AuditAction.invitationAccepted,
      summaryHebrew:
          'הצטרפות לחברה בתפקיד ${EnterpriseRoleLabels.hebrew(invite.role)}',
    );

    final memberSnap = await memberRef.get();
    return Membership.fromMap(memberSnap.id, memberSnap.data()!);
  }

  Future<void> _updateDeliveryStatus(String inviteId, String status) async {
    if (AppMode.isDemoMode) {
      await MockStore.instance.updateInvitationDeliveryStatus(
        inviteId: inviteId,
        deliveryStatus: status,
      );
      return;
    }
    await _invites.doc(inviteId).update({
      'deliveryStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static void _validateCreate({
    required OrganizationType orgType,
    required EnterpriseRole role,
    required String email,
    required bool canManage,
    List<EnterpriseRole> actorRoles = const [],
  }) {
    if (!canManage) throw Exception('אין הרשאה ליצור הזמנה');
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('יש להזין כתובת אימייל תקינה');
    }
    if (role == EnterpriseRole.platformAdmin) {
      throw Exception('לא ניתן להזמין כמנהל מערכת');
    }
    if (actorRoles.isNotEmpty &&
        !RoleInvitationPolicy.canAssignRole(
          orgType: orgType,
          actorRoles: actorRoles,
          targetRole: role,
        )) {
      throw Exception('אין הרשאה להזמין לתפקיד זה');
    }
    final valid = orgType == OrganizationType.supplier
        ? RoleInvitationPolicy.supplierLaunchRoles.contains(role) ||
            role.isSupplierRole
        : RoleInvitationPolicy.contractorLaunchRoles.contains(role) ||
            role.isContractorRole;
    if (!valid) throw Exception('תפקיד לא תואם לסוג הארגון');
  }

  static void _validateAccept({
    required OrganizationInvitation invite,
    required String uid,
    required String email,
  }) {
    if (invite.status != 'pending') {
      throw Exception('ההזמנה אינה פעילה');
    }
    if (invite.isExpired) throw Exception('תוקף ההזמנה פג');
    if (invite.email.toLowerCase() != email.trim().toLowerCase()) {
      throw Exception('ההזמנה אינה תואמת למשתמש המחובר');
    }
    if (uid.isEmpty) throw Exception('יש להתחבר כדי להצטרף');
  }
}

final emailInviteServiceProvider = Provider<EmailInviteService>(
  (ref) => DevInviteDeliveryService(),
);

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => InvitationRepository(
    emailService: ref.watch(emailInviteServiceProvider),
    auditRepository: ref.watch(auditRepositoryProvider),
  ),
);

final orgInvitationsProvider =
    StreamProvider.family<List<OrganizationInvitation>, String>((ref, orgId) {
  if (orgId.isEmpty) return Stream.value(const []);
  return ref.watch(invitationRepositoryProvider).watchInvitationsForOrg(orgId);
});

final invitationByIdProvider =
    FutureProvider.family<OrganizationInvitation?, String>((ref, inviteId) {
  return ref.watch(invitationRepositoryProvider).getInvitation(inviteId);
});

final pendingInvitationsForUserProvider =
    StreamProvider<List<OrganizationInvitation>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final email = session?.profile?.email ?? '';
  if (email.isEmpty) return Stream.value(const []);
  return ref.watch(invitationRepositoryProvider).watchPendingForEmail(email);
});

final pendingInvitationsCountProvider = Provider<int>((ref) {
  final invites =
      ref.watch(pendingInvitationsForUserProvider).valueOrNull ?? const [];
  return invites.where((i) => i.isPending).length;
});

final pendingOrgInvitationsCountProvider =
    Provider.family<int, String>((ref, orgId) {
  if (orgId.isEmpty) return 0;
  final invites =
      ref.watch(orgInvitationsProvider(orgId)).valueOrNull ?? const [];
  return invites.where((i) => i.isPending).length;
});
