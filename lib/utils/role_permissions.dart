import '../models/app_user.dart';
import '../models/user_type.dart';

/// Enterprise role helpers (foundation — login unchanged).
enum EnterpriseRole {
  customerAdmin,
  purchasing,
  engineer,
  supplier,
  admin,
}

abstract final class RolePermissions {
  static EnterpriseRole roleForUser(AppUser user) {
    if (user.userType.isSupplier) return EnterpriseRole.supplier;
    if (user.userType == UserType.commercialCustomer) {
      return EnterpriseRole.customerAdmin;
    }
    return EnterpriseRole.purchasing;
  }

  static bool canCreateRequest(AppUser user) => user.userType.isCustomer;

  static bool canApproveQuote(AppUser user) {
    final role = roleForUser(user);
    return role == EnterpriseRole.customerAdmin ||
        role == EnterpriseRole.purchasing ||
        role == EnterpriseRole.admin;
  }

  static bool canManageCatalog(AppUser user) {
    return roleForUser(user) == EnterpriseRole.admin;
  }

  static bool canRespondToRfq(AppUser user) => user.userType.isSupplier;

  static bool canEditSupplierCapabilities(AppUser user) =>
      user.userType.isSupplier;
}
