import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import 'supplier_quote_status.dart';

class ProjectWinningSupplierRow {
  const ProjectWinningSupplierRow({
    required this.requestId,
    required this.requestLabel,
    required this.supplierName,
    required this.totalAmount,
    required this.status,
    this.requestDate,
  });

  final String requestId;
  final String requestLabel;
  final String supplierName;
  final double totalAmount;
  final String status;
  final DateTime? requestDate;
}

class ProjectProcurementSummary {
  const ProjectProcurementSummary({
    required this.openRequests,
    required this.pendingQuotes,
    required this.approvedOrders,
    required this.totalApprovedCost,
    required this.winners,
  });

  static const empty = ProjectProcurementSummary(
    openRequests: 0,
    pendingQuotes: 0,
    approvedOrders: 0,
    totalApprovedCost: 0,
    winners: [],
  );

  final int openRequests;
  final int pendingQuotes;
  final int approvedOrders;
  final double totalApprovedCost;
  final List<ProjectWinningSupplierRow> winners;

  static ProjectProcurementSummary build({
    required String projectId,
    required List<QuoteRequest> requests,
    required List<SupplierQuote> quotes,
  }) {
    if (projectId.isEmpty) return empty;

    final projectRequests =
        requests.where((r) => r.projectId == projectId).toList();
    if (projectRequests.isEmpty) return empty;

    final quotesById = {for (final q in quotes) q.id: q};

    var openRequests = 0;
    var pendingQuotes = 0;
    var approvedOrders = 0;
    final winners = <ProjectWinningSupplierRow>[];
    var totalApprovedCost = 0.0;

    for (final request in projectRequests) {
      if (_isOpenRequest(request.status)) openRequests++;
      if (request.status == QuoteRequestStatus.quotesReceived) pendingQuotes++;

      final approvedId = request.approvedQuoteId;
      if (approvedId == null || approvedId.isEmpty) continue;

      final quote = quotesById[approvedId];
      if (quote == null) continue;
      if (!_isWinningQuoteStatus(quote.status)) continue;

      approvedOrders++;
      totalApprovedCost += quote.displayTotal;
      winners.add(
        ProjectWinningSupplierRow(
          requestId: request.id,
          requestLabel: request.projectName ?? request.customerName,
          supplierName: quote.supplierName,
          totalAmount: quote.displayTotal,
          status: SupplierQuoteStatus.displayLabel(quote.status),
          requestDate: request.createdAt,
        ),
      );
    }

    winners.sort(
      (a, b) => (b.requestDate ?? DateTime(2000))
          .compareTo(a.requestDate ?? DateTime(2000)),
    );

    return ProjectProcurementSummary(
      openRequests: openRequests,
      pendingQuotes: pendingQuotes,
      approvedOrders: approvedOrders,
      totalApprovedCost: totalApprovedCost,
      winners: winners,
    );
  }

  static bool _isOpenRequest(QuoteRequestStatus status) {
    return status == QuoteRequestStatus.sent ||
        status == QuoteRequestStatus.quotesReceived ||
        status == QuoteRequestStatus.pendingApproval ||
        status == QuoteRequestStatus.draft;
  }

  static bool _isWinningQuoteStatus(String status) {
    return status == SupplierQuoteStatus.approved ||
        status == SupplierQuoteStatus.shipped;
  }
}
