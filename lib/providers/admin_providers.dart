import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

final adminOverviewCountsProvider = FutureProvider<AdminOverviewCounts>((ref) {
  return ref.watch(adminRepositoryProvider).fetchCounts();
});

final adminRecentUsersProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).fetchRecentUsers();
});

final adminRecentProjectsProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).fetchRecentProjects();
});

final adminRecentRequestsProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).fetchRecentRequests();
});

final adminSuppliersProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).fetchSuppliers();
});

final adminRecentQuotesProvider = FutureProvider((ref) {
  return ref.watch(adminRepositoryProvider).fetchRecentQuotes();
});
