import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/project.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../repositories/audit_repository.dart';
import '../repositories/project_repository.dart';
import '../utils/project_procurement_summary.dart';
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
  final memberships =
      ref.watch(currentUserMembershipsProvider).valueOrNull ?? const [];
  return ref.watch(projectRepositoryProvider).watchAccessibleProjects(
        uid: uid,
        memberships: memberships,
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

final projectRequestsProvider =
    Provider.family<List<QuoteRequest>, String>((ref, projectId) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? const [];
  return requests
      .where((r) => r.projectId == projectId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final projectProcurementSummaryProvider =
    Provider.family<ProjectProcurementSummary, String>((ref, projectId) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? const [];
  final quotes =
      ref.watch(customerReceivedQuotesProvider).valueOrNull ?? const [];
  return ProjectProcurementSummary.build(
    projectId: projectId,
    requests: requests,
    quotes: quotes,
  );
});

final openRequestCountByProjectProvider = Provider<Map<String, int>>((ref) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? const [];
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
