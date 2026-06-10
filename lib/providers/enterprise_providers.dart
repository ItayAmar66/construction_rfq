import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/permission.dart';
import '../providers/providers.dart';
import '../repositories/organization_repository.dart';
import '../services/effective_permissions.dart';
import '../services/platform_admin.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(),
);

/// Memberships for current user (Firestore when migrated; empty otherwise).
final currentUserMembershipsProvider = StreamProvider<List<Membership>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(organizationRepositoryProvider).watchMembershipsForUser(uid);
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
  return ref.watch(effectivePermissionsProvider).contains(Permission.approveQuote);
});

final canCreateSupplierQuoteProvider = Provider<bool>((ref) {
  return ref
      .watch(effectivePermissionsProvider)
      .contains(Permission.createSupplierQuote);
});

final canMarkShippedProvider = Provider<bool>((ref) {
  return ref.watch(effectivePermissionsProvider).contains(Permission.markShipped);
});

final isPlatformAdminProvider = Provider<bool>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return false;
  if (EffectivePermissions.isPlatformAdmin(session.customClaims)) return true;
  final email = session.profile?.email ?? '';
  return PlatformAdmin.fromBootstrapAllowlist(
    uid: session.uid ?? '',
    email: email,
    allowedEmails: PlatformAdmin.bootstrapEmails,
  );
});
