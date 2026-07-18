import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/enterprise/audit_event.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/organization_type.dart';
import '../models/enterprise/permission.dart';
import '../models/enterprise/project.dart';
import '../repositories/admin_management_repository.dart';
import '../repositories/audit_repository.dart';
import '../repositories/organization_repository.dart';
import '../repositories/project_assignment_repository.dart';
import '../services/enterprise_permission_service.dart';
import '../utils/constants.dart';
import '../utils/enterprise_role_labels.dart';
import '../utils/team_permissions_policy.dart';

class TeamPermissionUpdateInput {
  const TeamPermissionUpdateInput({
    this.role,
    this.membershipStatus,
    this.accountStatus,
    this.projectIds,
    this.orgWideProjectAccess,
    this.managerUid,
    this.team,
    this.grants,
    this.revokes,
  });

  final EnterpriseRole? role;
  final String? membershipStatus;
  final AccountStatus? accountStatus;
  final List<String>? projectIds;
  final bool? orgWideProjectAccess;

  /// Empty string clears the manager. Informational only — never access.
  final String? managerUid;

  /// Empty string clears the team label. Informational only — never access.
  final String? team;
  final List<Permission>? grants;
  final List<Permission>? revokes;

  bool get hasMembershipFieldChanges =>
      orgWideProjectAccess != null ||
      managerUid != null ||
      team != null ||
      grants != null ||
      revokes != null;
}

class TeamPermissionsService {
  TeamPermissionsService({
    FirebaseFirestore? firestore,
    OrganizationRepository? organizationRepository,
    AdminManagementRepository? adminManagementRepository,
    ProjectAssignmentRepository? projectAssignmentRepository,
    AuditRepository? auditRepository,
  })  : _firestore = firestore,
        _organizationRepository =
            organizationRepository ?? OrganizationRepository(),
        _adminManagementRepository =
            adminManagementRepository ?? AdminManagementRepository(),
        _projectAssignmentRepository =
            projectAssignmentRepository ?? ProjectAssignmentRepository(),
        _auditRepository = auditRepository ?? AuditRepository();

  final FirebaseFirestore? _firestore;
  final OrganizationRepository _organizationRepository;
  final AdminManagementRepository _adminManagementRepository;
  final ProjectAssignmentRepository _projectAssignmentRepository;
  final AuditRepository _auditRepository;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<AppUser?> fetchUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    if (AppMode.isDemoMode) return null;
    try {
      final snap =
          await _db.collection(AppConstants.usersCollection).doc(uid).get();
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

    _validateGrantsAndRevokes(
      membership: membership,
      input: input,
      actorRoles: actorRoles,
      isPlatformAdmin: isPlatformAdmin,
    );

    if (input.orgWideProjectAccess != null &&
        orgType != OrganizationType.contractor) {
      throw Exception('גישה לפי פרויקטים זמינה רק בחברות קבלניות');
    }

    final role = input.role ?? membership.role;
    if (role == null && (input.role != null || input.projectIds != null)) {
      throw Exception('יש לבחור תפקיד');
    }

    final effectiveRole =
        role ?? membership.role ?? EnterpriseRole.contractorViewer;
    final projectIds = input.projectIds ?? membership.projectIds;

    if (isPlatformAdmin) {
      if (input.role != null ||
          input.membershipStatus != null ||
          input.projectIds != null ||
          input.hasMembershipFieldChanges) {
        await _adminManagementRepository.updateMembership(
          orgId: membership.orgId,
          uid: membership.uid,
          role: input.role,
          status: input.membershipStatus,
          projectIds: input.projectIds,
          orgWideProjectAccess: input.orgWideProjectAccess,
          managerUid: input.managerUid,
          team: input.team,
          grants: input.grants,
          revokes: input.revokes,
          actorUid: actorUid,
        );
      }
    } else {
      if (input.role != null && input.role != membership.role) {
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

      if (input.hasMembershipFieldChanges) {
        await _adminManagementRepository.updateMembership(
          orgId: membership.orgId,
          uid: membership.uid,
          orgWideProjectAccess: input.orgWideProjectAccess,
          managerUid: input.managerUid,
          team: input.team,
          grants: input.grants,
          revokes: input.revokes,
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

    await _recordSensitiveChangeAudits(
      membership: membership,
      orgType: orgType,
      actorUid: actorUid,
      actorEmail: actorEmail,
      actorName: actorName,
      input: input,
    );
  }

  /// Grants must be grantable and held by the actor; revokes cannot strip
  /// owner-management capability from an owner membership.
  void _validateGrantsAndRevokes({
    required Membership membership,
    required TeamPermissionUpdateInput input,
    required List<EnterpriseRole> actorRoles,
    required bool isPlatformAdmin,
  }) {
    final grants = input.grants;
    if (grants != null) {
      final actorPermissions = isPlatformAdmin
          ? Permission.values.toSet()
          : EnterprisePermissionService.permissionsForRoles(actorRoles);
      for (final p in grants) {
        if (!p.isGrantable) {
          throw Exception(
            'לא ניתן להעניק "${EnterpriseRoleLabels.permissionHebrew(p)}" כהרשאה מותאמת',
          );
        }
        if (!actorPermissions.contains(p)) {
          throw Exception(
            'אין לך הרשאת "${EnterpriseRoleLabels.permissionHebrew(p)}" ולכן לא ניתן להעניק אותה',
          );
        }
      }
    }

    final revokes = input.revokes;
    if (revokes != null) {
      final targetRole = input.role ?? membership.role;
      if (targetRole?.isOwnerRole == true) {
        for (final p in revokes) {
          if (!p.isGrantable) {
            throw Exception('לא ניתן להסיר הרשאות ניהול מבעלי הארגון');
          }
        }
      }
    }
  }

  Future<void> _recordSensitiveChangeAudits({
    required Membership membership,
    required OrganizationType orgType,
    required String actorUid,
    required String? actorEmail,
    required String? actorName,
    required TeamPermissionUpdateInput input,
  }) async {
    Future<void> record({
      required String action,
      required String summaryHebrew,
      Map<String, String> metadata = const {},
    }) {
      return AuditLogger.record(
        repository: _auditRepository,
        actorUid: actorUid,
        actorEmail: actorEmail,
        actorName: actorName,
        orgId: membership.orgId,
        orgType: orgType,
        entityType: AuditEntityType.membership,
        entityId: membership.uid,
        action: action,
        summaryHebrew: summaryHebrew,
        metadata: {'uid': membership.uid, ...metadata},
      );
    }

    if (input.orgWideProjectAccess != null &&
        input.orgWideProjectAccess != membership.orgWideProjectAccess) {
      await record(
        action: AuditAction.orgWideAccessChanged,
        summaryHebrew: input.orgWideProjectAccess!
            ? 'הוגדרה גישה לכל הפרויקטים'
            : 'הוגדרה גישה לפי שיוך פרויקטים',
        metadata: {'orgWide': input.orgWideProjectAccess.toString()},
      );
    }

    final grants = input.grants;
    if (grants != null) {
      final added = grants.where((p) => !membership.grants.contains(p));
      final removed = membership.grants.where((p) => !grants.contains(p));
      for (final p in added) {
        await record(
          action: AuditAction.permissionGranted,
          summaryHebrew:
              'הוענקה הרשאה: ${EnterpriseRoleLabels.permissionHebrew(p)}',
          metadata: {'permission': p.value},
        );
      }
      for (final p in removed) {
        await record(
          action: AuditAction.permissionRevoked,
          summaryHebrew:
              'הוסרה הרשאה מותאמת: ${EnterpriseRoleLabels.permissionHebrew(p)}',
          metadata: {'permission': p.value},
        );
      }
    }

    final revokes = input.revokes;
    if (revokes != null) {
      final added = revokes.where((p) => !membership.revokes.contains(p));
      final removed = membership.revokes.where((p) => !revokes.contains(p));
      for (final p in added) {
        await record(
          action: AuditAction.permissionRevoked,
          summaryHebrew:
              'נחסמה הרשאה: ${EnterpriseRoleLabels.permissionHebrew(p)}',
          metadata: {'permission': p.value, 'revoke': 'true'},
        );
      }
      for (final p in removed) {
        await record(
          action: AuditAction.permissionGranted,
          summaryHebrew:
              'הוסרה חסימת הרשאה: ${EnterpriseRoleLabels.permissionHebrew(p)}',
          metadata: {'permission': p.value, 'revoke': 'false'},
        );
      }
    }

    if (input.membershipStatus == 'disabled' &&
        membership.status != 'disabled') {
      await record(
        action: AuditAction.membershipDisabled,
        summaryHebrew: 'החברות בארגון הושבתה',
      );
    } else if (input.membershipStatus == 'active' &&
        membership.status != 'active') {
      await record(
        action: AuditAction.membershipActivated,
        summaryHebrew: 'החברות בארגון הופעלה מחדש',
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
    final added =
        nextProjectIds.where((id) => !previousProjectIds.contains(id));
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
