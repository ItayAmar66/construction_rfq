import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import 'supplier_quote_status.dart';

/// One construction project as seen from the supplier side, scoped to a
/// single contractor. Aggregated purely from the requests/quotes the
/// supplier already has visibility into — no new collections required.
class SupplierProjectGroup {
  const SupplierProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.projectLocation,
    required this.requests,
    required this.isNew,
  });

  final String projectId;
  final String projectName;
  final String projectLocation;
  final List<QuoteRequest> requests;
  final bool isNew;

  DateTime get latestActivity =>
      requests.map((r) => r.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);

  int get newRfqCount =>
      requests.where((r) => r.status == QuoteRequestStatus.sent).length;
}

/// One contractor (company or individual) as seen from the supplier side —
/// the parent of one or more construction projects.
class SupplierContractorGroup {
  const SupplierContractorGroup({
    required this.key,
    required this.name,
    required this.requests,
    required this.projects,
    required this.isNew,
  });

  final String key;
  final String name;
  final List<QuoteRequest> requests;
  final List<SupplierProjectGroup> projects;
  final bool isNew;

  DateTime get latestActivity =>
      requests.map((r) => r.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);

  int get newRfqCount =>
      requests.where((r) => r.status == QuoteRequestStatus.sent).length;

  int get activeProjectCount => projects.length;
}

String contractorKeyFor(QuoteRequest request) {
  final orgId = request.contractorOrgId;
  if (orgId != null && orgId.isNotEmpty) return orgId;
  return request.customerId;
}

const _newSinceDuration = Duration(days: 14);

/// Groups the supplier-visible requests into a contractor → project tree.
List<SupplierContractorGroup> buildSupplierContractorGroups(
  List<QuoteRequest> requests,
) {
  final now = DateTime.now();
  final byContractor = <String, List<QuoteRequest>>{};
  for (final r in requests) {
    byContractor.putIfAbsent(contractorKeyFor(r), () => []).add(r);
  }

  final groups = <SupplierContractorGroup>[];
  byContractor.forEach((key, contractorRequests) {
    final byProject = <String, List<QuoteRequest>>{};
    for (final r in contractorRequests) {
      final projectId = r.projectId;
      if (projectId == null || projectId.isEmpty) continue;
      byProject.putIfAbsent(projectId, () => []).add(r);
    }

    final projects = byProject.entries.map((entry) {
      final projectRequests = entry.value
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final first = projectRequests.first;
      final earliestForProject = projectRequests
          .map((r) => r.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      return SupplierProjectGroup(
        projectId: entry.key,
        projectName: first.projectName ?? first.siteName ?? 'פרויקט',
        projectLocation: first.projectLocation ?? '',
        requests: projectRequests,
        isNew: now.difference(earliestForProject) <= _newSinceDuration,
      );
    }).toList()
      ..sort((a, b) => b.latestActivity.compareTo(a.latestActivity));

    final sortedRequests = [...contractorRequests]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final earliestForContractor = contractorRequests
        .map((r) => r.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    groups.add(
      SupplierContractorGroup(
        key: key,
        name: sortedRequests.first.customerName,
        requests: sortedRequests,
        projects: projects,
        isNew: now.difference(earliestForContractor) <= _newSinceDuration,
      ),
    );
  });

  groups.sort((a, b) => b.latestActivity.compareTo(a.latestActivity));
  return groups;
}

/// Approved/active order rows for a set of requests, joined with the
/// supplier's own quotes so totals reflect the supplier's submitted price.
class SupplierOrderRow {
  const SupplierOrderRow({
    required this.request,
    required this.quote,
  });

  final QuoteRequest request;
  final SupplierQuote quote;
}

List<SupplierOrderRow> supplierOrdersFor(
  List<QuoteRequest> requests,
  List<SupplierQuote> quotes,
) {
  final quoteById = {for (final q in quotes) q.id: q};
  final rows = <SupplierOrderRow>[];
  for (final r in requests) {
    final approvedId = r.approvedQuoteId;
    if (approvedId == null || approvedId.isEmpty) continue;
    final quote = quoteById[approvedId];
    if (quote == null) continue;
    if (quote.status != SupplierQuoteStatus.approved &&
        quote.status != SupplierQuoteStatus.shipped) {
      continue;
    }
    rows.add(SupplierOrderRow(request: r, quote: quote));
  }
  rows.sort((a, b) => b.request.createdAt.compareTo(a.request.createdAt));
  return rows;
}
