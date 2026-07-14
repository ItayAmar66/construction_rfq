import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quote_request.dart';
import '../utils/supplier_hierarchy.dart';
import 'providers.dart';

/// All requests the current supplier has visibility into (new + quoted +
/// fulfilled + historical), joined back from ids on their SupplierQuote
/// docs since those don't carry contractor/project context themselves.
final supplierAllRequestsProvider = FutureProvider<List<QuoteRequest>>((ref) async {
  final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
  final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];
  final toFulfill = ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
  final history = ref.watch(supplierOrderHistoryProvider).valueOrNull ?? [];

  final byId = {for (final r in incoming) r.id: r};
  final missingIds = {
    for (final q in [...sent, ...toFulfill, ...history])
      if (!byId.containsKey(q.quoteRequestId)) q.quoteRequestId,
  }.toList();

  if (missingIds.isNotEmpty) {
    final fetched =
        await ref.watch(quoteServiceProvider).getRequestsByIds(missingIds);
    for (final r in fetched) {
      byId[r.id] = r;
    }
  }

  return byId.values.toList();
});

/// Contractor → project tree built from [supplierAllRequestsProvider].
final supplierContractorGroupsProvider =
    Provider<List<SupplierContractorGroup>>((ref) {
  final requests = ref.watch(supplierAllRequestsProvider).valueOrNull ?? [];
  return buildSupplierContractorGroups(requests);
});

final supplierContractorGroupProvider =
    Provider.family<SupplierContractorGroup?, String>((ref, contractorKey) {
  final groups = ref.watch(supplierContractorGroupsProvider);
  for (final g in groups) {
    if (g.key == contractorKey) return g;
  }
  return null;
});

final supplierProjectGroupProvider =
    Provider.family<SupplierProjectGroup?, String>((ref, projectId) {
  final groups = ref.watch(supplierContractorGroupsProvider);
  for (final g in groups) {
    for (final p in g.projects) {
      if (p.projectId == projectId) return p;
    }
  }
  return null;
});
