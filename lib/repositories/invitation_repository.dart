import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_mode.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization_invitation.dart';
import '../models/enterprise/organization_type.dart';
import '../providers/providers.dart';
import '../services/mock_store.dart';
import '../utils/constants.dart';

class InvitationRepository {
  InvitationRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  static const _uuid = Uuid();

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection(AppConstants.invitationsCollection);

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
    String? displayName,
    required bool canManage,
  }) async {
    _validateCreate(
      orgType: orgType,
      role: role,
      email: email,
      canManage: canManage,
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
      invitedByUid: invitedByUid,
      invitedByName: invitedByName,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
    );
    if (AppMode.isDemoMode) {
      return MockStore.instance.createInvitation(invite);
    }
    await _invites.doc(invite.id).set({
      ...invite.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(invite.expiresAt!),
    });
    return invite;
  }

  Future<void> cancelInvitation({
    required String inviteId,
    required bool canManage,
  }) async {
    if (!canManage) {
      throw Exception('אין הרשאה לבטל הזמנה');
    }
    if (AppMode.isDemoMode) {
      MockStore.instance.cancelInvitation(inviteId);
      return;
    }
    await _invites.doc(inviteId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Membership> acceptInvitation({
    required String inviteId,
    required String uid,
    required String email,
  }) async {
    if (AppMode.isDemoMode) {
      return MockStore.instance.acceptInvitation(
        inviteId: inviteId,
        uid: uid,
        email: email,
      );
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
      'orgId': invite.orgId,
      'orgType': invite.orgType.value,
      'roles': [invite.role.value],
      'status': 'active',
      'acceptedInvitationId': inviteId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await inviteRef.update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final memberSnap = await memberRef.get();
    return Membership.fromMap(memberSnap.id, memberSnap.data()!);
  }

  static void _validateCreate({
    required OrganizationType orgType,
    required EnterpriseRole role,
    required String email,
    required bool canManage,
  }) {
    if (!canManage) throw Exception('אין הרשאה ליצור הזמנה');
    if (email.trim().isEmpty || !email.contains('@')) {
      throw Exception('יש להזין כתובת אימייל תקינה');
    }
    if (role == EnterpriseRole.platformAdmin) {
      throw Exception('לא ניתן להזמין כמנהל מערכת');
    }
    final valid = orgType == OrganizationType.supplier
        ? role.isSupplierRole
        : role.isContractorRole;
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
    if (invite.email.toLowerCase() != email.trim().toLowerCase()) {
      throw Exception('ההזמנה אינה תואמת למשתמש המחובר');
    }
    if (uid.isEmpty) throw Exception('יש להתחבר כדי להצטרף');
  }
}

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => InvitationRepository(),
);

final orgInvitationsProvider =
    StreamProvider.family<List<OrganizationInvitation>, String>((ref, orgId) {
  if (orgId.isEmpty) return Stream.value(const []);
  return ref.watch(invitationRepositoryProvider).watchInvitationsForOrg(orgId);
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
