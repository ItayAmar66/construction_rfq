import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/organization_type.dart';
import 'role_invitation_policy.dart';

/// Who can view or edit team permissions in an organization.
abstract final class TeamPermissionsPolicy {
  static bool canViewTeam({
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required OrganizationType orgType,
  }) {
    if (isPlatformAdmin) return true;
    if (orgType == OrganizationType.contractor) {
      return actorRoles.any(
        (r) => [
          EnterpriseRole.contractorCompanyOwner,
          EnterpriseRole.procurementManager,
          EnterpriseRole.projectManager,
        ].contains(r),
      );
    }
    return actorRoles.contains(EnterpriseRole.supplierOwner);
  }

  static bool canEditMemberPermissions({
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required OrganizationType orgType,
    required String actorUid,
    required String targetUid,
  }) {
    if (actorUid == targetUid) return false;
    if (isPlatformAdmin) return true;
    if (orgType == OrganizationType.contractor) {
      return actorRoles.contains(EnterpriseRole.contractorCompanyOwner);
    }
    return actorRoles.contains(EnterpriseRole.supplierOwner);
  }

  static bool canEditProjectAccess({
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required OrganizationType orgType,
  }) {
    if (orgType != OrganizationType.contractor) return false;
    if (isPlatformAdmin) return true;
    return actorRoles.contains(EnterpriseRole.contractorCompanyOwner) ||
        actorRoles.contains(EnterpriseRole.projectManager);
  }

  static bool canOnlyViewProjectAccess({
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required OrganizationType orgType,
  }) {
    if (isPlatformAdmin) return false;
    if (orgType != OrganizationType.contractor) return false;
    return actorRoles.contains(EnterpriseRole.procurementManager) &&
        !canEditMemberPermissions(
          isPlatformAdmin: isPlatformAdmin,
          actorRoles: actorRoles,
          orgType: orgType,
          actorUid: 'actor',
          targetUid: 'target',
        );
  }

  static String? readOnlyMessage({
    required bool isPlatformAdmin,
    required List<EnterpriseRole> actorRoles,
    required OrganizationType orgType,
  }) {
    if (canEditMemberPermissions(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
      actorUid: 'a',
      targetUid: 'b',
    )) {
      return null;
    }
    if (canOnlyViewProjectAccess(
      isPlatformAdmin: isPlatformAdmin,
      actorRoles: actorRoles,
      orgType: orgType,
    )) {
      return 'רק מנהל חברה יכול לשנות הרשאות';
    }
    return 'אין הרשאת ניהול צוות';
  }

  static List<EnterpriseRole> assignableRoles({
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
    required bool isPlatformAdmin,
  }) {
    if (isPlatformAdmin) {
      return orgType == OrganizationType.contractor
          ? RoleInvitationPolicy.contractorLaunchRoles
          : RoleInvitationPolicy.supplierLaunchRoles;
    }
    return RoleInvitationPolicy.assignableRoles(
      orgType: orgType,
      actorRoles: actorRoles,
    );
  }
}
