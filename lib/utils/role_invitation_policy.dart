import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/organization_type.dart';

/// Which roles an actor may invite or assign inside an organization.
abstract final class RoleInvitationPolicy {
  static const contractorLaunchRoles = [
    EnterpriseRole.contractorCompanyOwner,
    EnterpriseRole.procurementManager,
    EnterpriseRole.engineer,
    EnterpriseRole.contractorViewer,
  ];

  /// Supplier launch: owner, sales rep (procurement), viewer.
  static const supplierLaunchRoles = [
    EnterpriseRole.supplierOwner,
    EnterpriseRole.supplierSalesRep,
    EnterpriseRole.supplierViewer,
  ];

  static List<EnterpriseRole> assignableRoles({
    required OrganizationType orgType,
    required List<EnterpriseRole> actorRoles,
  }) {
    if (orgType == OrganizationType.contractor) {
      if (actorRoles.contains(EnterpriseRole.contractorCompanyOwner)) {
        return contractorLaunchRoles;
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
}
