import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/project.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../repositories/audit_repository.dart';
import '../repositories/organization_repository.dart';
import '../repositories/project_repository.dart';
import '../utils/project_procurement_summary.dart';
import '../utils/procurement_rfq_access.dart';
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
