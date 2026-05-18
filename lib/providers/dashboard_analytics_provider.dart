import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../utils/supplier_quote_status.dart';
import 'providers.dart';

class CustomerDashboardAnalytics {
  const CustomerDashboardAnalytics({
    required this.totalRequests,
    required this.activeRequests,
    required this.receivedQuotesCount,
    required this.approvedOrders,
    required this.monthlySpending,
    required this.unreadQuotes,
    required this.unreadRequestUpdates,
    required this.recentQuotes,
    required this.recentRequests,
  });

  final int totalRequests;
  final int activeRequests;
  final int receivedQuotesCount;
  final int approvedOrders;
  final double monthlySpending;
  final int unreadQuotes;
  final int unreadRequestUpdates;
  final List<SupplierQuote> recentQuotes;
  final List<QuoteRequest> recentRequests;
}

class SupplierDashboardAnalytics {
  const SupplierDashboardAnalytics({
    required this.incomingCount,
    required this.sentQuotesCount,
    required this.approvedOrders,
    required this.ordersInProgress,
    required this.monthlyRevenue,
    required this.winRatePercent,
    required this.unseenIncoming,
    required this.unreadOrders,
    required this.recentQuotes,
    required this.recentRequests,
  });

  final int incomingCount;
  final int sentQuotesCount;
  final int approvedOrders;
  final int ordersInProgress;
  final double monthlyRevenue;
  final int winRatePercent;
  final int unseenIncoming;
  final int unreadOrders;
  final List<SupplierQuote> recentQuotes;
  final List<QuoteRequest> recentRequests;
}

bool _isThisMonth(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month;
}

final customerDashboardAnalyticsProvider =
    Provider<CustomerDashboardAnalytics>((ref) {
  final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
  final quotes = ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];

  final active = requests.where((r) {
    return r.status == QuoteRequestStatus.sent ||
        r.status == QuoteRequestStatus.quotesReceived ||
        r.status == QuoteRequestStatus.ordered;
  }).length;

  final approved = requests.where((r) {
    return r.status == QuoteRequestStatus.ordered ||
        r.status == QuoteRequestStatus.shipped ||
        r.status == QuoteRequestStatus.completed;
  }).length;

  final monthlySpending = quotes
      .where(
        (q) =>
            q.status == SupplierQuoteStatus.approved &&
            _isThisMonth(q.createdAt),
      )
      .fold<double>(0, (s, q) => s + q.displayTotal);

  final sortedQuotes = [...quotes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final sortedRequests = [...requests]..sort((a, b) => b.sortDate.compareTo(a.sortDate));

  return CustomerDashboardAnalytics(
    totalRequests: requests.length,
    activeRequests: active,
    receivedQuotesCount: quotes.length,
    approvedOrders: approved,
    monthlySpending: monthlySpending,
    unreadQuotes: quotes.where((q) => q.isUnreadByCustomer).length,
    unreadRequestUpdates:
        requests.where((r) => r.hasUnreadStatusForCustomer()).length,
    recentQuotes: sortedQuotes.take(5).toList(),
    recentRequests: sortedRequests.take(5).toList(),
  );
});

final supplierDashboardAnalyticsProvider =
    Provider<SupplierDashboardAnalytics>((ref) {
  final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
  final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];
  final toFulfill = ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
  final history = ref.watch(supplierOrderHistoryProvider).valueOrNull ?? [];
  final supplierId = ref.watch(authSessionProvider).valueOrNull?.profile?.id;

  final approved = [...toFulfill, ...history]
      .where((q) => q.status == SupplierQuoteStatus.approved || q.status == SupplierQuoteStatus.shipped)
      .toList();

  final monthlyRevenue = history
      .where((q) => _isThisMonth(q.createdAt))
      .fold<double>(0, (s, q) => s + q.displayTotal);

  final sentCount = sent.length;
  final won = history.length;
  final winRate = sentCount + won == 0 ? 0 : ((won / (sentCount + won)) * 100).round();

  final sortedQuotes = [...sent, ...toFulfill]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return SupplierDashboardAnalytics(
    incomingCount: incoming.length,
    sentQuotesCount: sent.length,
    approvedOrders: approved.length,
    ordersInProgress: toFulfill.length,
    monthlyRevenue: monthlyRevenue,
    winRatePercent: winRate,
    unseenIncoming: supplierId == null
        ? 0
        : incoming.where((r) => r.isUnseenBySupplier(supplierId)).length,
    unreadOrders: toFulfill.where((q) => q.isUnreadOrderBySupplier).length,
    recentQuotes: sortedQuotes.take(5).toList(),
    recentRequests: ([...incoming]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        .take(5)
        .toList(),
  );
});
