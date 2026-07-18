import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/organization_type.dart';

/// Which roles an actor may invite or assign inside an organization.
/// Only canonical role values appear here — deprecated roles are readable
/// but never assignable.
abstract final class RoleInvitationPolicy {
  static const contractorLaunchRoles = [
    EnterpriseRole.contractorOwner,
    EnterpriseRole.contractorAdmin,
    EnterpriseRole.procurementManager,
    EnterpriseRole.projectManager,
    EnterpriseRole.engineer,
    EnterpriseRole.contractorViewer,
  ];

  static const contractorApprovalRoles = [
    EnterpriseRole.contractorAdmin,
    EnterpriseRole.procurementManager,
    EnterpriseRole.projectManager,
    EnterpriseRole.engineer,
    EnterpriseRole.contractorViewer,
  ];

  static const supplierLaunchRoles = [
    EnterpriseRole.supplierOwner,
    EnterpriseRole.supplierAdmin,
    EnterpriseRole.supplierSales,
    EnterpriseRole.supplierOperations,
    EnterpriseRole.supplierViewer,
  ];

  static const supplierApprovalRoles = [
    EnterpriseRole.supplierAdmin,
    EnterpriseRole.supplierSales,
    EnterpriseRole.supplierOperations,
    EnterpriseRole.supplierViewer,
  ];

  static List<EnterpriseRole> assignableRoles({
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
  }) {
    if (orgType == OrganizationType.contractor) {
      if (actorRoles.contains(EnterpriseRole.contractorOwner)) {
        return contractorLaunchRoles;
      }
      // Admins manage the team but cannot hand out ownership.
      if (actorRoles.contains(EnterpriseRole.contractorAdmin)) {
        return contractorApprovalRoles;
      }
      if (actorRoles.contains(EnterpriseRole.procurementManager)) {
        return const [
          EnterpriseRole.engineer,
          EnterpriseRole.contractorViewer,
        ];
      }
      return const [];
    }

    if (orgType == OrganizationType.supplier) {
      if (actorRoles.contains(EnterpriseRole.supplierOwner)) {
        return supplierLaunchRoles;
      }
      if (actorRoles.contains(EnterpriseRole.supplierAdmin)) {
        return supplierApprovalRoles;
      }
      return const [];
    }

    return const [];
  }

  static bool canAssignRole({
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
    required EnterpriseRole targetRole,
  }) {
    return assignableRoles(orgType: orgType, actorRoles: actorRoles)
        .contains(targetRole);
  }

  static bool canManageTeam({
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
  }) {
    if (orgType == OrganizationType.contractor) {
      return actorRoles.contains(EnterpriseRole.contractorOwner) ||
          actorRoles.contains(EnterpriseRole.contractorAdmin);
    }
    if (orgType == OrganizationType.supplier) {
      return actorRoles.contains(EnterpriseRole.supplierOwner) ||
          actorRoles.contains(EnterpriseRole.supplierAdmin);
    }
    return false;
  }
}
