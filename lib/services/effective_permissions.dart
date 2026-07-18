import '../models/app_user.dart';
import '../models/enterprise/enterprise_role.dart';
import '../models/enterprise/membership.dart';
import '../models/enterprise/permission.dart';
import '../models/user_type.dart';
import '../utils/org_id_helpers.dart';
import 'enterprise_permission_service.dart';
import 'platform_admin.dart';

/// Why a user holds (or lost) a permission.
enum PermissionSource {
  role,
  customGrant,
  revoked,
  platformAdmin,
}

/// Deterministic effective-access resolution for one membership:
/// role permissions + narrow grants − revokes (revokes always win).
class EffectiveAccess {
  const EffectiveAccess({
    required this.permissions,
    required this.sources,
    this.isPlatformAdmin = false,
  });

  final Set<Permission> permissions;

  /// Source per permission — includes revoked entries (not in [permissions]).
  final Map<Permission, PermissionSource> sources;
  final bool isPlatformAdmin;

  bool can(Permission permission) => permissions.contains(permission);

  PermissionSource? sourceOf(Permission permission) => sources[permission];

  static const empty = EffectiveAccess(permissions: {}, sources: {});

  static EffectiveAccess forMembership(Membership membership) {
    if (!membership.isActive) return empty;
    final fromRole =
        EnterprisePermissionService.permissionsForRoles(membership.roles);
    final sources = <Permission, PermissionSource>{};
    final effective = <Permission>{};

    for (final p in fromRole) {
      sources[p] = PermissionSource.role;
      effective.add(p);
    }
    for (final p in membership.grants) {
      // Grants only add narrowly scoped, grantable exceptions.
      if (!p.isGrantable) continue;
      if (!effective.contains(p)) {
        sources[p] = PermissionSource.customGrant;
        effective.add(p);
      }
    }
    for (final p in membership.revokes) {
      // Owner management capability cannot be stripped via revokes UI-side;
      // rules additionally protect owner memberships.
      if (membership.role?.isOwnerRole == true && !p.isGrantable) continue;
      effective.remove(p);
      sources[p] = PermissionSource.revoked;
    }
    return EffectiveAccess(permissions: effective, sources: sources);
  }

  static EffectiveAccess platformAdminAccess() => EffectiveAccess(
        permissions: Permission.values.toSet(),
        sources: {
          for (final p in Permission.values) p: PermissionSource.platformAdmin,
        },
        isPlatformAdmin: true,
      );
}

/// Effective permissions with enterprise membership + legacy userType fallback.
abstract final class EffectivePermissions {
  static Set<Permission> resolve({
    required AppUser? user,
    List<Membership> memberships = const [],
    Map<String, dynamic>? customClaims,
  }) {
    return resolveAccess(
      user: user,
      memberships: memberships,
      customClaims: customClaims,
    ).permissions;
  }

  /// Full resolution including per-permission sources.
  static EffectiveAccess resolveAccess({
    required AppUser? user,
    List<Membership> memberships = const [],
    Map<String, dynamic>? customClaims,
  }) {
    if (user == null) return EffectiveAccess.empty;

    if (PlatformAdmin.fromCustomClaims(customClaims)) {
      return EffectiveAccess.platformAdminAccess();
    }

    if (!user.accountStatus.canUsePlatform) {
      return const EffectiveAccess(
        permissions: {Permission.viewCatalog},
        sources: {Permission.viewCatalog: PermissionSource.role},
      );
    }

    final active = memberships.where((m) => m.isActive).toList();
    if (active.isNotEmpty) {
      final permissions = <Permission>{};
      final sources = <Permission, PermissionSource>{};
      for (final membership in active) {
        final access = EffectiveAccess.forMembership(membership);
        for (final p in access.permissions) {
          permissions.add(p);
          // Prefer role over grant as the reported source across memberships.
          final existing = sources[p];
          final incoming = access.sources[p] ?? PermissionSource.role;
          if (existing == null ||
              existing == PermissionSource.revoked ||
              incoming == PermissionSource.role) {
            sources[p] = incoming;
          }
        }
        for (final entry in access.sources.entries) {
          sources.putIfAbsent(entry.key, () => entry.value);
        }
      }
      return EffectiveAccess(permissions: permissions, sources: sources);
    }

    // Live web: membership collection-group queries may be unavailable while the
    // user profile already carries a real supplier org id from bootstrap.
    if (user.userType == UserType.commercialSupplier &&
        user.accountStatus.canUsePlatform &&
        OrgIdHelpers.isRealOrgId(user.supplierOrgId)) {
      final permissions = EnterprisePermissionService.permissionsForRoles(
        const [EnterpriseRole.supplierOwner],
      );
      return EffectiveAccess(
        permissions: permissions,
        sources: {for (final p in permissions) p: PermissionSource.role},
      );
    }

    // No self-serve legacy owner permissions — invite or admin approval required.
    return const EffectiveAccess(
      permissions: {Permission.viewCatalog},
      sources: {Permission.viewCatalog: PermissionSource.role},
    );
  }

  static bool hasPlatformAccess({
    required AppUser? user,
    List<Membership> memberships = const [],
    Map<String, dynamic>? customClaims,
  }) {
    if (user == null) return false;
    if (PlatformAdmin.fromCustomClaims(customClaims)) return true;
    if (!user.accountStatus.canUsePlatform) return false;
    if (memberships.any((m) => m.isActive)) return true;
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
      can(user, Permission.markOrderShipped,
          memberships: memberships, customClaims: customClaims);

  static bool canConfirmShipmentReceipt(AppUser? user,
          {List<Membership> memberships = const [],
          Map<String, dynamic>? customClaims}) =>
      can(user, Permission.confirmDeliveryReceipt,
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
      can(user, Permission.approveRfq,
          memberships: memberships, customClaims: customClaims);

  static bool isPlatformAdmin(Map<String, dynamic>? customClaims) =>
      PlatformAdmin.fromCustomClaims(customClaims);
}
