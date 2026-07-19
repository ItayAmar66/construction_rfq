import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/project.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../repositories/audit_repository.dart';
import '../repositories/organization_repository.dart';
import '../repositories/project_assignment_repository.dart';
import '../repositories/project_repository.dart';
import '../utils/project_procurement_summary.dart';
import '../utils/procurement_rfq_access.dart';
import '../utils/shipment_receipt_access.dart';
import 'enterprise_providers.dart';
import 'providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(
    auditRepository: ref.watch(auditRepositoryProvider),
  ),
);

final currentUserProjectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchAccessibleProjectsForUser(
        uid,
        ref.watch(organizationRepositoryProvider).watchMembershipsForUser(uid),
      );
});

final deletionPendingProjectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchDeletionPendingForOwner(uid);
});

final projectProvider = StreamProvider.family<Project?, String>((ref, projectId) {
  if (projectId.isEmpty) return Stream.value(null);
  return ref.watch(projectRepositoryProvider).watchProject(projectId);
});

/// Project completion/deletion is pure per-project ownership server-side
/// (firestore.rules' projectOwnerUpdateAllowed requires
/// resource.data.ownerUid == uid(), or platform admin) — NOT an org-role
/// permission. A Permission.manageProjects-based check would show these
/// buttons to any org admin/procurement manager viewing ANY project in
/// their org, including ones they don't own, which the server always
/// rejects. These resolve the specific project and check ownership to
/// match what the server will actually allow.
bool _isProjectOwnerOrPlatformAdmin(Ref ref, String projectId) {
  if (ref.watch(hasPlatformAdminClaimProvider)) return true;
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return false;
  final project = ref.watch(projectProvider(projectId)).valueOrNull;
  return project != null && project.ownerUid == uid;
}

final canCompleteProjectProvider = Provider.family<bool, String>(
  (ref, projectId) => _isProjectOwnerOrPlatformAdmin(ref, projectId),
);

final canDeleteProjectProvider = Provider.family<bool, String>(
  (ref, projectId) => _isProjectOwnerOrPlatformAdmin(ref, projectId),
);

final contractorOrgRequestsProvider = StreamProvider<List<QuoteRequest>>((ref) {
  final orgId = ref.watch(primaryOrgIdProvider);
  if (orgId == null || orgId.isEmpty) return Stream.value(const []);
  return ref.watch(quoteServiceProvider).watchContractorOrgRequests(orgId);
});

List<QuoteRequest> mergeQuoteRequestsById(
  List<QuoteRequest> first, [
  List<QuoteRequest> second = const [],
]) {
  final byId = <String, QuoteRequest>{};
  for (final request in [...first, ...second]) {
    byId[request.id] = request;
  }
  return byId.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

List<QuoteRequest> _projectScopedRequests(
  List<QuoteRequest> requests,
  String projectId,
) {
  return requests
      .where((r) => r.projectId == projectId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

final projectRequestsProvider =
    Provider.family<List<QuoteRequest>, String>((ref, projectId) {
  final customer =
      ref.watch(customerRequestsProvider).valueOrNull ?? const [];
  final org =
      ref.watch(contractorOrgRequestsProvider).valueOrNull ?? const [];
  return _projectScopedRequests(mergeQuoteRequestsById(customer, org), projectId);
});

final projectProcurementSummaryProvider =
    Provider.family<ProjectProcurementSummary, String>((ref, projectId) {
  final customer =
      ref.watch(customerRequestsProvider).valueOrNull ?? const [];
  final org =
      ref.watch(contractorOrgRequestsProvider).valueOrNull ?? const [];
  final requests = _projectScopedRequests(
    mergeQuoteRequestsById(customer, org),
    projectId,
  );
  final quotes =
      ref.watch(customerReceivedQuotesProvider).valueOrNull ?? const [];
  return ProjectProcurementSummary.build(
    projectId: projectId,
    requests: requests,
    quotes: quotes,
  );
});

final openRequestCountByProjectProvider = Provider<Map<String, int>>((ref) {
  final customer =
      ref.watch(customerRequestsProvider).valueOrNull ?? const [];
  final org =
      ref.watch(contractorOrgRequestsProvider).valueOrNull ?? const [];
  final requests = mergeQuoteRequestsById(customer, org);
  final counts = <String, int>{};
  for (final request in requests) {
    final projectId = request.projectId;
    if (projectId == null || projectId.isEmpty) continue;
    if (request.status.isLocked ||
        request.status == QuoteRequestStatus.cancelled ||
        request.status == QuoteRequestStatus.closed) {
      continue;
    }
    counts[projectId] = (counts[projectId] ?? 0) + 1;
  }
  return counts;
});

final canApproveQuoteForRequestProvider =
    Provider.family<bool, String>((ref, requestId) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final actorUid = session?.uid;
  if (actorUid == null || actorUid.isEmpty) return false;
  if (!ref.watch(canApproveQuoteProvider)) return false;

  final request = ref.watch(quoteRequestProvider(requestId)).valueOrNull;
  if (request == null) return false;

  final memberships =
      ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
  final orgId = ref.watch(primaryOrgIdProvider);
  final projectId = request.projectId;
  final projectOrgId = projectId != null && projectId.isNotEmpty
      ? ref.watch(projectProvider(projectId)).valueOrNull?.orgId
      : null;

  return ProcurementRfqAccess.canApproveQuoteForRequest(
    actorUid: actorUid,
    request: request,
    memberships: memberships,
    orgId: orgId,
    projectOrgId: projectOrgId,
  );
});

final canConfirmShipmentReceiptForRequestProvider =
    Provider.family<bool, String>((ref, requestId) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final actorUid = session?.uid;
  if (actorUid == null || actorUid.isEmpty) return false;
  if (!ref.watch(canConfirmShipmentReceiptProvider)) return false;

  final request = ref.watch(quoteRequestProvider(requestId)).valueOrNull;
  if (request == null) return false;

  final memberships =
      ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
  final orgId = ref.watch(primaryOrgIdProvider);
  final projectId = request.projectId;
  final projectOrgId = projectId != null && projectId.isNotEmpty
      ? ref.watch(projectProvider(projectId)).valueOrNull?.orgId
      : null;
  // Prefer the live assignment subcollection over membership.projectIds
  // (a derived cache that can go stale — see ProjectAssignmentRepository/
  // InvitationRepository) so a removed teammate doesn't keep seeing this
  // action, and a freshly-assigned one doesn't have to wait on a cache
  // write that may never land.
  final liveProjectAssigneeUids = projectId != null && projectId.isNotEmpty
      ? (ref.watch(projectAssignmentsProvider(projectId)).valueOrNull ?? const [])
          .map((a) => a.uid)
          .toSet()
      : null;

  return ShipmentReceiptAccess.canConfirmReceiptForRequest(
    actorUid: actorUid,
    request: request,
    liveProjectAssigneeUids: liveProjectAssigneeUids,
    memberships: memberships,
    orgId: orgId,
    projectOrgId: projectOrgId,
  );
});
