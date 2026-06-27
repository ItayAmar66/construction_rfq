import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/access_request.dart';
import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/organization_type.dart';
import '../models/enterprise/project.dart';
import '../repositories/access_request_repository.dart';
import '../repositories/audit_repository.dart';
import '../utils/constants.dart';
import '../utils/role_invitation_policy.dart';

class UserApprovalService {
  UserApprovalService({
    FirebaseFirestore? firestore,
    AccessRequestRepository? accessRequestRepository,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _accessRequests =
            accessRequestRepository ?? AccessRequestRepository(firestore: firestore),
        _auditRepository = auditRepository ?? AuditRepository(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final AccessRequestRepository _accessRequests;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<List<AccessRequest>> fetchPendingForOrg(String orgId) =>
      _accessRequests.fetchPendingForOrg(orgId);

  Future<List<AccessRequest>> fetchAllPending() =>
      _accessRequests.fetchAllPending();

  Future<List<Project>> fetchProjectsForOrg(String orgId) async {
    if (orgId.isEmpty) return const [];
    if (AppMode.isDemoMode) return const [];

    final snap = await _db
        .collection(AppConstants.projectsCollection)
        .where('orgId', isEqualTo: orgId)
        .get();
    return snap.docs.map((d) => Project.fromMap(d.id, d.data())).toList();
  }

  Future<void> approveAccessRequest({
    required AccessRequest request,
    required String orgId,
    required OrganizationType orgType,
    required EnterpriseRole role,
    required String actorUid,
    String? actorName,
    String? actorEmail,
    List<String> projectIds = const [],
  }) async {
    _validateApprovalRole(orgType: orgType, role: role);

    if (AppMode.isDemoMode) {
      await _accessRequests.resolveRequest(
        uid: request.uid,
        status: 'approved',
        actorUid: actorUid,
      );
      return;
    }

    final userRef = _db.collection(AppConstants.usersCollection).doc(request.uid);
    final memberRef = _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(request.uid);

    await _db.runTransaction((tx) async {
      tx.update(userRef, {
        'accountStatus': AccountStatus.active.value,
        'orgId': orgId,
        'primaryOrgId': orgId,
        if (orgType == OrganizationType.supplier) 'supplierOrgId': orgId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(memberRef, {
        'uid': request.uid,
        'orgId': orgId,
        'orgType': orgType.value,
        'roles': [role.value],
        'status': 'active',
        'projectIds': projectIds,
        'email': request.email.trim().toLowerCase(),
        'displayName': request.fullName.trim(),
        'createdBy': actorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    for (final projectId in projectIds) {
      if (projectId.isEmpty) continue;
      await _db
          .collection(AppConstants.projectsCollection)
          .doc(projectId)
          .collection('assignments')
          .doc(request.uid)
          .set({
        'projectId': projectId,
        'orgId': orgId,
        'uid': request.uid,
        'role': role.value,
        'displayName': request.fullName.trim(),
        'email': request.email.trim().toLowerCase(),
        'assignedByUid': actorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _accessRequests.resolveRequest(
      uid: request.uid,
      status: 'approved',
      actorUid: actorUid,
    );

    try {
      await AuditLogger.record(
        repository: _auditRepository,
        actorUid: actorUid,
        actorEmail: actorEmail,
        actorName: actorName,
        orgId: orgId,
        orgType: orgType,
        entityType: AuditEntityType.membership,
        entityId: request.uid,
        action: AuditAction.membershipApproved,
        summaryHebrew: 'המשתמש אושר בהצלחה',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[UserApproval] audit failed: $e');
    }
  }

  Future<void> rejectAccessRequest({
    required AccessRequest request,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) {
      await _accessRequests.resolveRequest(
        uid: request.uid,
        status: 'rejected',
        actorUid: actorUid,
      );
      return;
    }

    await _db.collection(AppConstants.usersCollection).doc(request.uid).update({
      'accountStatus': AccountStatus.rejected.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _accessRequests.resolveRequest(
      uid: request.uid,
      status: 'rejected',
      actorUid: actorUid,
    );
  }

  Future<void> disableUser({
    required String uid,
    required String orgId,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) return;

    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'accountStatus': AccountStatus.disabled.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(uid)
        .update({
      'status': 'disabled',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': actorUid,
    });
  }

  Future<void> reactivateUser({
    required String uid,
    required String orgId,
    required String actorUid,
  }) async {
    if (AppMode.isDemoMode) return;

    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'accountStatus': AccountStatus.active.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.membershipsSubcollection)
        .doc(uid)
        .update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': actorUid,
    });
  }

  static List<EnterpriseRole> approvalRolesFor({
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
    required bool isPlatformAdmin,
  }) {
    if (isPlatformAdmin) {
      return orgType == OrganizationType.supplier
          ? RoleInvitationPolicy.supplierApprovalRoles
          : RoleInvitationPolicy.contractorApprovalRoles;
    }
    if (orgType == OrganizationType.contractor &&
        actorRoles.contains(EnterpriseRole.contractorCompanyOwner)) {
      return RoleInvitationPolicy.contractorApprovalRoles;
    }
    if (orgType == OrganizationType.supplier &&
        actorRoles.contains(EnterpriseRole.supplierOwner)) {
      return RoleInvitationPolicy.supplierApprovalRoles;
    }
    return RoleInvitationPolicy.assignableRoles(
      orgType: orgType,
      actorRoles: actorRoles,
    );
  }

  void _validateApprovalRole({
    required OrganizationType orgType,
    required EnterpriseRole role,
  }) {
    if (role == EnterpriseRole.platformAdmin) {
      throw Exception('לא ניתן להקצות מנהל מערכת');
    }
    final allowed = orgType == OrganizationType.contractor
        ? RoleInvitationPolicy.contractorApprovalRoles
        : RoleInvitationPolicy.supplierApprovalRoles;
    if (!allowed.contains(role)) {
      throw Exception('תפקיד לא חוקי לארגון זה');
    }
  }

  static bool canApproveUsers({
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required OrganizationType orgType,
  }) {
    if (isPlatformAdmin) return true;
    if (orgType == OrganizationType.contractor) {
      return actorRoles.contains(EnterpriseRole.contractorCompanyOwner);
    }
    return actorRoles.contains(EnterpriseRole.supplierOwner);
  }
}
