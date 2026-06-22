import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/permission.dart';
import '../models/user_type.dart';
import '../utils/org_id_helpers.dart';
import 'enterprise_permission_service.dart';
import 'platform_admin.dart';

/// Effective permissions with enterprise membership + legacy userType fallback.
abstract final class EffectivePermissions {
  static Set<Permission> resolve({
    required AppUser? user,
    List<Membership> memberships = const [],
    Map<String, dynamic>? customClaims,
  }) {
    if (user == null) return {};

    if (PlatformAdmin.fromCustomClaims(customClaims)) {
      return Permission.values.toSet();
    }

    if (!user.accountStatus.canUsePlatform) {
      return {Permission.viewCatalog};
    }

    final active = memberships.where((m) => m.status == 'active').toList();
    if (active.isNotEmpty) {
      return active
          .expand(EnterprisePermissionService.permissionsForMembership)
          .toSet();
    }

    // Live web: membership collection-group queries may be unavailable while the
    // user profile already carries a real supplier org id from bootstrap.
    if (user.userType == UserType.commercialSupplier &&
        user.accountStatus.canUsePlatform &&
        OrgIdHelpers.isRealOrgId(user.supplierOrgId)) {
      return EnterprisePermissionService.permissionsForRoles(
        const [EnterpriseRole.supplierOwner],
      );
    }

    // No self-serve legacy owner permissions — invite or admin approval required.
    return {Permission.viewCatalog};
  }

  static bool hasPlatformAccess({
    required AppUser? user,
    List<Membership> memberships = const [],
    Map<String, dynamic>? customClaims,
  }) {
    if (user == null) return false;
    if (PlatformAdmin.fromCustomClaims(customClaims)) return true;
    if (!user.accountStatus.canUsePlatform) return false;
    if (memberships.any((m) => m.status == 'active')) return true;
    if (user.userType == UserType.commercialSupplier &&
        user.accountStatus.canUsePlatform &&
        OrgIdHelpers.isRealOrgId(user.supplierOrgId)) {
      return true;
    }
    if (user.userType == UserType.commercialCustomer &&
        user.accountStatus.canUsePlatform &&
        OrgIdHelpers.isRealOrgId(user.supplierOrgId)) {
      return true;
    }
    return false;
  }

  static bool can(AppUser? user, Permission permission,
      {List<Membership> memberships = const [],
      Map<String, dynamic>? customClaims}) {
    return resolve(
      user: user,
      memberships: memberships,
      customClaims: customClaims,
    ).contains(permission);
  }

  static bool canSubmitRfq(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.submitRfq,
          memberships: memberships, customClaims: customClaims);

  static bool canApproveQuote(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.approveQuote,
          memberships: memberships, customClaims: customClaims);

  static bool canCreateSupplierQuote(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.createSupplierQuote,
          memberships: memberships, customClaims: customClaims);

  static bool canMarkShipped(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.markShipped,
          memberships: memberships, customClaims: customClaims);

  static bool canManageOrgUsers(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.manageUsers,
          memberships: memberships, customClaims: customClaims);

  static bool canManageProjects(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.manageProjects,
          memberships: memberships, customClaims: customClaims);

  static bool canApproveProcurementRfq(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.approveProcurementRfq,
          memberships: memberships, customClaims: customClaims);

  static bool isPlatformAdmin(Map<String, dynamic>? customClaims) =>
      PlatformAdmin.fromCustomClaims(customClaims);
}
