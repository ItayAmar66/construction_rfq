import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/membership.dart';
import '../models/enterprise/organization.dart';
import '../models/enterprise/organization_invitation.dart';
import '../models/enterprise/permission.dart';
import '../models/quote_request.dart';
import '../providers/providers.dart';
import '../repositories/audit_repository.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/organization_repository.dart';
import '../services/effective_permissions.dart';
import '../services/quote_service.dart';
import '../utils/membership_identity_enricher.dart';
import '../utils/org_id_helpers.dart';
import '../utils/platform_access_gate.dart';

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

/// True once memberships resolve or bootstrap timeout elapses.
final membershipBootstrapSettledProvider = Provider<bool>((ref) {
  final memberships = ref.watch(currentUserMembershipsProvider);
  if (memberships.hasValue || memberships.hasError) return true;
  return ref.watch(_membershipBootstrapTimeoutProvider).maybeWhen(
        data: (_) => true,
        orElse: () => false,
      );
});

final _membershipBootstrapTimeoutProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return true;
  await Future<void>.delayed(PlatformAccessGateResolver.bootstrapTimeout);
  return true;
});

final platformAccessGateProvider = Provider<PlatformAccessGate>((ref) {
  if (!ref.watch(authBootstrapSettledProvider)) {
    return PlatformAccessGate.loading;
  }
  final session = ref.watch(resolvedAuthSessionProvider).valueOrNull;
  if (session == null || !session.isAuthenticated) {
    return PlatformAccessGate.noPermission;
  }
  return PlatformAccessGateResolver.resolve(
    isAuthenticated: session.isAuthenticated,
    membershipSettled: ref.watch(membershipBootstrapSettledProvider),
    hasPlatformAccess: ref.watch(hasPlatformAccessProvider),
    accountStatus: session.profile?.accountStatus,
    membershipLoadError: ref.watch(currentUserMembershipsProvider).hasError,
    isPlatformAdmin: ref.watch(hasPlatformAdminClaimProvider),
  );
});

final orgMembershipsProvider =
    StreamProvider.family<List<Membership>, String>((ref, orgId) {
  if (orgId.isEmpty) return Stream.value(const []);
  return _combineOrgMemberships(
    ref.watch(organizationRepositoryProvider).watchMembershipsForOrg(orgId),
    ref.watch(invitationRepositoryProvider).watchInvitationsForOrg(orgId),
  );
});

Stream<List<Membership>> _combineOrgMemberships(
  Stream<List<Membership>> memberships,
  Stream<List<OrganizationInvitation>> invitations,
) {
  final controller = StreamController<List<Membership>>();
  var latestMemberships = const <Membership>[];
  var latestInvitations = const <OrganizationInvitation>[];
  StreamSubscription<List<Membership>>? membershipSub;
  StreamSubscription<List<OrganizationInvitation>>? invitationSub;
  var publishScheduled = false;

  void publish() {
    if (controller.isClosed) return;
    if (publishScheduled) return;
    publishScheduled = true;
    scheduleMicrotask(() {
      publishScheduled = false;
      if (controller.isClosed) return;
      controller.add(
        MembershipIdentityEnricher.enrich(
          memberships: latestMemberships,
          invitations: latestInvitations,
        ),
      );
    });
  }

  controller.onListen = () {
    membershipSub = memberships.listen((value) {
      latestMemberships = value;
      publish();
    });
    invitationSub = invitations.listen((value) {
      latestInvitations = value;
      publish();
    });
  };
  controller.onCancel = () async {
    await membershipSub?.cancel();
    await invitationSub?.cancel();
  };
  return controller.stream;
}

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

/// Procurement/owner — may send RFQ to suppliers after internal approval.
final canSubmitRfqProvider = Provider<bool>((ref) {
  return ref.watch(hasPlatformAccessProvider) &&
      ref.watch(effectivePermissionsProvider).contains(Permission.submitRfq);
});

/// Engineer + procurement — may create/submit internal material requests.
final canSubmitMaterialRequestProvider = Provider<bool>((ref) {
  if (!ref.watch(hasPlatformAccessProvider)) return false;
  final perms = ref.watch(effectivePermissionsProvider);
  return perms.contains(Permission.submitRfq) ||
      (perms.contains(Permission.createDraft) &&
          perms.contains(Permission.addItems));
});

final canInviteCompanyMembersProvider = Provider<bool>((ref) {
  if (!ref.watch(hasPlatformAccessProvider)) return false;
  final perms = ref.watch(effectivePermissionsProvider);
  return perms.contains(Permission.manageUsers) ||
      perms.contains(Permission.inviteMembers);
});

final hasPlatformAccessProvider = Provider<bool>((ref) {
  final session = ref.watch(resolvedAuthSessionProvider).valueOrNull;
  return EffectivePermissions.hasPlatformAccess(
    user: session?.profile,
    memberships: ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [],
    customClaims: session?.customClaims,
  );
});

final canApproveProcurementRfqProvider = Provider<bool>((ref) {
  return ref.watch(hasPlatformAccessProvider) &&
      ref.watch(effectivePermissionsProvider)
          .contains(Permission.approveProcurementRfq);
});

final primaryOrgIdProvider = Provider<String?>((ref) {
  final memberships =
      ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
  if (memberships.isNotEmpty) return memberships.first.orgId;

  final profile = ref.watch(authSessionProvider).valueOrNull?.profile;
  if (profile == null) return null;
  return OrgIdHelpers.isRealOrgId(profile.supplierOrgId)
      ? profile.supplierOrgId
      : null;
});

final orgPendingProcurementRequestsProvider =
    StreamProvider<List<QuoteRequest>>((ref) {
  final orgId = ref.watch(primaryOrgIdProvider);
  if (orgId == null || orgId.isEmpty) return Stream.value(<QuoteRequest>[]);
  return ref.watch(quoteServiceProvider).watchOrgPendingProcurement(orgId);
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

final canCreateProjectProvider = Provider<bool>((ref) {
  if (!ref.watch(hasPlatformAccessProvider)) return false;
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
