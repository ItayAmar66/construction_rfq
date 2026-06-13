import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/permission.dart';
import '../providers/providers.dart';
import '../repositories/audit_repository.dart';
import '../repositories/organization_repository.dart';
import '../services/effective_permissions.dart';
import '../services/organization_bootstrap_service.dart';

final organizationBootstrapServiceProvider =
    Provider<OrganizationBootstrapService>(
  (ref) => OrganizationBootstrapService(),
);

/// Ensures commercial accounts have a real org + owner membership after login.
final ensureOrgBootstrapProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final profile = session?.profile;
  if (profile == null || !OrganizationBootstrapService.shouldBootstrapOrg(profile.userType)) {
    return;
  }
  final memberships =
      ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
  if (memberships.any((m) => m.status == 'active')) return;
  await ref.read(organizationBootstrapServiceProvider).ensureOwnerOrganization(
        user: profile,
        existingMemberships: memberships,
      );
  ref.invalidate(currentUserMembershipsProvider);
});

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(
    auditRepository: ref.watch(auditRepositoryProvider),
  ),
);

/// Memberships for current user (Firestore when migrated; empty otherwise).
final currentUserMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(organizationRepositoryProvider).watchMembershipsForUser(uid);
});

final orgMembershipsProvider =
    StreamProvider.family<List<Membership>, String>((ref, orgId) {
  if (orgId.isEmpty) return Stream.value(const []);
  return ref
      .watch(organizationRepositoryProvider)
      .watchMembershipsForOrg(orgId);
});

final currentPrimaryOrganizationProvider = Provider<Organization?>((ref) {
  ref.watch(currentUserMembershipsProvider);
  return null;
});

final effectivePermissionsProvider = Provider<Set<Permission>>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final memberships =
      ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
  return EffectivePermissions.resolve(
    user: session?.profile,
    memberships: memberships,
    customClaims: session?.customClaims,
  );
});

final canSubmitRfqProvider = Provider<bool>((ref) {
  return ref.watch(effectivePermissionsProvider).contains(Permission.submitRfq);
});

final canApproveQuoteProvider = Provider<bool>((ref) {
  return ref
      .watch(effectivePermissionsProvider)
      .contains(Permission.approveQuote);
});

final canCreateSupplierQuoteProvider = Provider<bool>((ref) {
  return ref
      .watch(effectivePermissionsProvider)
      .contains(Permission.createSupplierQuote);
});

final canMarkShippedProvider = Provider<bool>((ref) {
  return ref
      .watch(effectivePermissionsProvider)
      .contains(Permission.markShipped);
});

final canCompleteProjectProvider = Provider<bool>((ref) {
  final perms = ref.watch(effectivePermissionsProvider);
  return perms.contains(Permission.manageProjects) ||
      perms.contains(Permission.submitRfq);
});

final canDeleteProjectProvider = Provider<bool>((ref) {
  return ref
      .watch(effectivePermissionsProvider)
      .contains(Permission.manageProjects);
});

final canManageCompanyRolesProvider = Provider<bool>((ref) {
  return ref
      .watch(effectivePermissionsProvider)
      .contains(Permission.manageUsers);
});

final hasPlatformAdminClaimProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  return EffectivePermissions.isPlatformAdmin(session?.customClaims);
});

final showAdminNavProvider = hasPlatformAdminClaimProvider;

/// UI nav/admin entry — requires platformAdmin custom claim in production.
final isPlatformAdminProvider = hasPlatformAdminClaimProvider;
