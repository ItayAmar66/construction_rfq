import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/permission.dart';

/// Canonical role → permission matrix. Single source of truth for what each
/// organization role may do; mirrored by `firestore.rules`.
abstract final class EnterprisePermissionService {
  static Set<Permission> permissionsForRole(EnterpriseRole role) {
    return Set.unmodifiable(_rolePermissions[role] ?? const <Permission>{});
  }

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

  static const _contractorAdminPermissions = <Permission>{
    Permission.viewOrganization,
    Permission.manageOrganizationSettings,
    Permission.viewUsers,
    Permission.inviteUsers,
    Permission.manageUsers,
    Permission.manageRoles,
    Permission.viewProjects,
    Permission.manageProjects,
    Permission.assignProjectMembers,
    Permission.viewRfqs,
    Permission.createRfqDraft,
    Permission.editRfqDraft,
    Permission.submitRfq,
    Permission.approveRfq,
    Permission.rejectRfq,
    Permission.viewQuotes,
    Permission.approveQuote,
    Permission.rejectQuote,
    Permission.viewOrders,
    Permission.placeOrder,
    Permission.manageOrders,
    Permission.viewDeliveries,
    Permission.confirmDeliveryReceipt,
    Permission.reportDeliveryIssue,
    Permission.viewAnalytics,
    Permission.viewFinancialData,
    Permission.viewCatalog,
    Permission.viewAuditLog,
  };

  static const _supplierAdminPermissions = <Permission>{
    Permission.viewOrganization,
    Permission.manageOrganizationSettings,
    Permission.viewUsers,
    Permission.inviteUsers,
    Permission.manageUsers,
    Permission.manageRoles,
    Permission.viewRfqs,
    Permission.viewQuotes,
    Permission.createSupplierQuote,
    Permission.editSupplierQuote,
    Permission.submitSupplierQuote,
    Permission.viewOrders,
    Permission.markOrderShipped,
    Permission.viewDeliveries,
    Permission.manageDeliveries,
    Permission.viewAnalytics,
    Permission.viewFinancialData,
    Permission.viewCatalog,
    Permission.viewAuditLog,
  };

  static final _rolePermissions = <EnterpriseRole, Set<Permission>>{
    EnterpriseRole.platformAdmin: Permission.values.toSet(),
    EnterpriseRole.contractorOwner: _contractorAdminPermissions,
    EnterpriseRole.contractorAdmin: _contractorAdminPermissions,
    EnterpriseRole.procurementManager: {
      Permission.viewOrganization,
      Permission.viewUsers,
      Permission.inviteUsers,
      Permission.viewProjects,
      Permission.viewRfqs,
      Permission.createRfqDraft,
      Permission.editRfqDraft,
      Permission.submitRfq,
      Permission.approveRfq,
      Permission.rejectRfq,
      Permission.viewQuotes,
      Permission.approveQuote,
      Permission.rejectQuote,
      Permission.viewOrders,
      Permission.placeOrder,
      Permission.manageOrders,
      Permission.viewDeliveries,
      Permission.confirmDeliveryReceipt,
      Permission.reportDeliveryIssue,
      Permission.viewAnalytics,
      Permission.viewFinancialData,
      Permission.viewCatalog,
    },
    EnterpriseRole.projectManager: {
      Permission.viewOrganization,
      Permission.viewUsers,
      Permission.viewProjects,
      Permission.assignProjectMembers,
      Permission.viewRfqs,
      Permission.createRfqDraft,
      Permission.editRfqDraft,
      Permission.viewQuotes,
      Permission.viewOrders,
      Permission.viewDeliveries,
      Permission.confirmDeliveryReceipt,
      Permission.reportDeliveryIssue,
      Permission.viewAnalytics,
      Permission.viewCatalog,
    },
    EnterpriseRole.engineer: {
      Permission.viewOrganization,
      Permission.viewProjects,
      Permission.viewRfqs,
      Permission.createRfqDraft,
      Permission.editRfqDraft,
      Permission.viewDeliveries,
      Permission.confirmDeliveryReceipt,
      Permission.reportDeliveryIssue,
      Permission.viewCatalog,
    },
    EnterpriseRole.contractorViewer: {
      Permission.viewOrganization,
      Permission.viewProjects,
      Permission.viewRfqs,
      Permission.viewOrders,
      Permission.viewDeliveries,
      Permission.viewAnalytics,
      Permission.viewCatalog,
    },
    EnterpriseRole.supplierOwner: _supplierAdminPermissions,
    EnterpriseRole.supplierAdmin: _supplierAdminPermissions,
    EnterpriseRole.supplierSales: {
      Permission.viewOrganization,
      Permission.viewRfqs,
      Permission.viewQuotes,
      Permission.createSupplierQuote,
      Permission.editSupplierQuote,
      Permission.submitSupplierQuote,
      Permission.viewOrders,
      Permission.viewAnalytics,
      Permission.viewCatalog,
    },
    EnterpriseRole.supplierOperations: {
      Permission.viewOrganization,
      Permission.viewOrders,
      Permission.markOrderShipped,
      Permission.viewDeliveries,
      Permission.manageDeliveries,
      Permission.viewCatalog,
    },
    EnterpriseRole.supplierViewer: {
      Permission.viewOrganization,
      Permission.viewRfqs,
      Permission.viewQuotes,
      Permission.viewOrders,
      Permission.viewDeliveries,
      Permission.viewAnalytics,
      Permission.viewCatalog,
    },
  };
}
