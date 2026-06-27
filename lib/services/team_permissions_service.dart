import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization_type.dart';
import '../models/enterprise/project.dart';
import '../repositories/admin_management_repository.dart';
import '../repositories/organization_repository.dart';
import '../repositories/project_assignment_repository.dart';
import '../utils/constants.dart';
import '../utils/team_permissions_policy.dart';

class TeamPermissionUpdateInput {
  const TeamPermissionUpdateInput({
    this.role,
    this.membershipStatus,
    this.accountStatus,
    this.projectIds,
  });

  final EnterpriseRole? role;
  final String? membershipStatus;
  final AccountStatus? accountStatus;
  final List<String>? projectIds;
}

class TeamPermissionsService {
  TeamPermissionsService({
    FirebaseFirestore? firestore,
    OrganizationRepository? organizationRepository,
    AdminManagementRepository? adminManagementRepository,
    ProjectAssignmentRepository? projectAssignmentRepository,
  })  : _firestore = firestore,
        _organizationRepository =
            organizationRepository ?? OrganizationRepository(),
        _adminManagementRepository =
            adminManagementRepository ?? AdminManagementRepository(),
        _projectAssignmentRepository =
            projectAssignmentRepository ?? ProjectAssignmentRepository();

  final FirebaseFirestore? _firestore;
  final OrganizationRepository _organizationRepository;
  final AdminManagementRepository _adminManagementRepository;
  final ProjectAssignmentRepository _projectAssignmentRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<AppUser?> fetchUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    if (AppMode.isDemoMode) return null;
    try {
      final snap = await _db.collection(AppConstants.usersCollection).doc(uid).get();
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(snap.id, snap.data()!);
    } catch (e) {
      if (kDebugMode) debugPrint('[TeamPermissions] fetchUserProfile: $e');
      return null;
    }
  }

  Future<List<Project>> fetchProjectsForOrg(String orgId) async {
    if (orgId.isEmpty) return const [];
    if (AppMode.isDemoMode) return const [];
    final snap = await _db
        .collection(AppConstants.projectsCollection)
        .where('orgId', isEqualTo: orgId)
        .get();
    return snap.docs.map((d) => Project.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> updateMemberPermissions({
    required Membership membership,
    required OrganizationType orgType,
    required String actorUid,
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required TeamPermissionUpdateInput input,
    String? actorEmail,
    String? actorName,
  }) async {
    if (!TeamPermissionsPolicy.canEditMemberPermissions(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
      actorUid: actorUid,
      targetUid: membership.uid,
    )) {
      throw Exception('אין הרשאה לערוך הרשאות משתמש זה');
    }

    final allowedRoles = TeamPermissionsPolicy.assignableRoles(
      orgType: orgType,
      actorRoles: actorRoles,
      isPlatformAdmin: isPlatformAdmin,
    );

    if (input.role != null && !allowedRoles.contains(input.role)) {
      throw Exception('תפקיד לא מותר');
    }

    final role = input.role ?? membership.roles.firstOrNull;
    if (role == null && (input.role != null || input.projectIds != null)) {
      throw Exception('יש לבחור תפקיד');
    }

    final effectiveRole = role ?? membership.roles.firstOrNull ?? EnterpriseRole.contractorViewer;
    final projectIds = input.projectIds ?? membership.projectIds;

    if (isPlatformAdmin &&
        (input.role != null ||
            input.membershipStatus != null ||
            input.projectIds != null)) {
      await _adminManagementRepository.updateMembership(
        orgId: membership.orgId,
        uid: membership.uid,
        role: input.role,
        status: input.membershipStatus,
        projectIds: input.projectIds,
        actorUid: actorUid,
      );
    } else if (!isPlatformAdmin) {
      if (input.role != null &&
          input.role != membership.roles.firstOrNull) {
        await _organizationRepository.updateMemberRole(
          orgId: membership.orgId,
          memberUid: membership.uid,
          newRole: input.role!,
          actorUid: actorUid,
          orgType: orgType,
          actorEmail: actorEmail,
          actorName: actorName,
        );
      }

      if (input.membershipStatus != null &&
          input.membershipStatus != membership.status) {
        await _adminManagementRepository.updateMembership(
          orgId: membership.orgId,
          uid: membership.uid,
          status: input.membershipStatus,
          actorUid: actorUid,
        );
      }

      if (input.projectIds != null &&
          orgType == OrganizationType.contractor &&
          TeamPermissionsPolicy.canEditProjectAccess(
            isPlatformAdmin: isPlatformAdmin,
            actorRoles: actorRoles,
            orgType: orgType,
          )) {
        await _syncProjectAccess(
          orgId: membership.orgId,
          uid: membership.uid,
          role: effectiveRole,
          actorUid: actorUid,
          previousProjectIds: membership.projectIds,
          nextProjectIds: projectIds,
          actorRoles: actorRoles,
          isPlatformAdmin: isPlatformAdmin,
        );
        await _adminManagementRepository.updateMembership(
          orgId: membership.orgId,
          uid: membership.uid,
          projectIds: projectIds,
          actorUid: actorUid,
        );
      }
    }

    if (input.accountStatus != null) {
      await _updateAccountStatus(
        uid: membership.uid,
        status: input.accountStatus!,
        actorUid: actorUid,
        isPlatformAdmin: isPlatformAdmin,
      );
    } else if (input.membershipStatus == 'disabled' &&
        membership.status != 'disabled') {
      await _updateAccountStatus(
        uid: membership.uid,
        status: AccountStatus.disabled,
        actorUid: actorUid,
        isPlatformAdmin: isPlatformAdmin,
      );
    } else if (input.membershipStatus == 'active' &&
        membership.status == 'disabled') {
      await _updateAccountStatus(
        uid: membership.uid,
        status: AccountStatus.active,
        actorUid: actorUid,
        isPlatformAdmin: isPlatformAdmin,
      );
    }

    if (isPlatformAdmin &&
        input.projectIds != null &&
        orgType == OrganizationType.contractor) {
      await _syncProjectAccess(
        orgId: membership.orgId,
        uid: membership.uid,
        role: effectiveRole,
        actorUid: actorUid,
        previousProjectIds: membership.projectIds,
        nextProjectIds: projectIds,
        actorRoles: actorRoles,
        isPlatformAdmin: isPlatformAdmin,
      );
    }
  }

  Future<void> _syncProjectAccess({
    required String orgId,
    required String uid,
    required EnterpriseRole role,
    required String actorUid,
    required List<String> previousProjectIds,
    required List<String> nextProjectIds,
    required List<EnterpriseRole> actorRoles,
    required bool isPlatformAdmin,
  }) async {
    final added = nextProjectIds.where((id) => !previousProjectIds.contains(id));
    final removed =
        previousProjectIds.where((id) => !nextProjectIds.contains(id));

    final canManageProjects = TeamPermissionsPolicy.canEditProjectAccess(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: OrganizationType.contractor,
    );

    for (final projectId in added) {
      await _projectAssignmentRepository.assignUserToProject(
        projectId: projectId,
        orgId: orgId,
        uid: uid,
        role: role,
        actorUid: actorUid,
        canManage: canManageProjects,
        displayName: null,
        email: null,
      );
    }

    for (final projectId in removed) {
      await _projectAssignmentRepository.removeProjectAssignment(
        projectId: projectId,
        uid: uid,
        canManage: canManageProjects,
        actorUid: actorUid,
        orgId: orgId,
      );
    }
  }

  Future<void> _updateAccountStatus({
    required String uid,
    required AccountStatus status,
    required String actorUid,
    required bool isPlatformAdmin,
  }) async {
    if (AppMode.isDemoMode) return;
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'accountStatus': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
