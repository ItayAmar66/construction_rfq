import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/permission.dart';

/// Role → capability matrix for enterprise hierarchy.
abstract final class EnterprisePermissionService {
  static Set<Permission> permissionsForRoles(Iterable<EnterpriseRole> roles) {
    final out = <Permission>{};
    for (final role in roles) {
      out.addAll(_rolePermissions[role] ?? const {});
    }
    return out;
  }

  static Set<Permission> permissionsForMembership(Membership membership) {
    if (membership.status != 'active') return {};
    return permissionsForRoles(membership.roles);
  }

  static bool can(Iterable<EnterpriseRole> roles, Permission permission) {
    return permissionsForRoles(roles).contains(permission);
  }

  static final _rolePermissions = <EnterpriseRole, Set<Permission>>{
    EnterpriseRole.platformAdmin: Permission.values.toSet(),
    EnterpriseRole.contractorCompanyOwner: {
      Permission.viewCatalog,
      Permission.createDraft,
      Permission.addItems,
      Permission.submitRfq,
      Permission.approveQuote,
      Permission.rejectQuote,
      Permission.manageUsers,
      Permission.manageProjects,
      Permission.viewReports,
    },
    EnterpriseRole.procurementManager: {
      Permission.viewCatalog,
      Permission.createDraft,
      Permission.addItems,
      Permission.submitRfq,
      Permission.approveQuote,
      Permission.rejectQuote,
      Permission.viewReports,
    },
    EnterpriseRole.projectManager: {
      Permission.viewCatalog,
      Permission.createDraft,
      Permission.addItems,
      Permission.viewReports,
    },
    EnterpriseRole.engineer: {
      Permission.viewCatalog,
      Permission.createDraft,
      Permission.addItems,
    },
    EnterpriseRole.contractorViewer: {
      Permission.viewCatalog,
      Permission.viewReports,
    },
    EnterpriseRole.supplierOwner: {
      Permission.viewCatalog,
      Permission.createSupplierQuote,
      Permission.markShipped,
      Permission.manageUsers,
      Permission.viewReports,
    },
    EnterpriseRole.supplierSalesManager: {
      Permission.viewCatalog,
      Permission.createSupplierQuote,
      Permission.viewReports,
    },
    EnterpriseRole.supplierSalesRep: {
      Permission.viewCatalog,
      Permission.createSupplierQuote,
    },
    EnterpriseRole.supplierOps: {
      Permission.viewCatalog,
      Permission.markShipped,
    },
    EnterpriseRole.supplierViewer: {
      Permission.viewCatalog,
      Permission.viewReports,
    },
  };
}
