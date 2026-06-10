import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enterprise/project.dart';
import '../models/quote_status.dart';
import '../repositories/project_repository.dart';
import 'providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(),
);

final currentUserProjectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(authSessionProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchProjectsForOwner(uid);
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
