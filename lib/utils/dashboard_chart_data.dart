import 'package:flutter/material.dart';

import '../data/mock_dashboard_charts.dart';
import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../utils/app_theme.dart';
import '../utils/supplier_quote_status.dart';

/// Builds live chart series from app data (fallback to empty).
abstract final class DashboardChartData {
  static const _monthLabels = [
    'ינו׳',
    'פבר׳',
    'מרץ',
    'אפר׳',
    'מאי',
    'יוני',
    'יולי',
    'אוג׳',
    'ספט׳',
    'אוק׳',
    'נוב׳',
    'דצמ׳',
  ];

  static const _weekLabels = ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳'];

  static List<ChartDataPoint> lastSixMonthsSpend(
    List<SupplierQuote> approvedQuotes,
  ) {
    final now = DateTime.now();
    final points = <ChartDataPoint>[];
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final total = approvedQuotes
          .where(
            (q) =>
                q.status == SupplierQuoteStatus.approved &&
                q.createdAt.year == month.year &&
                q.createdAt.month == month.month,
          )
          .fold<double>(0, (s, q) => s + q.displayTotal);
      points.add(
        ChartDataPoint(
          label: _monthLabels[month.month - 1],
          value: total,
        ),
      );
    }
    return points;
  }

  static List<ChartDataPoint> requestsThisWeek(List<QuoteRequest> requests) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday % 7));
    final counts = List<double>.filled(7, 0);
    for (final r in requests) {
      final d = r.createdAt;
      if (d.isBefore(start) || d.isAfter(now.add(const Duration(days: 1)))) {
        continue;
      }
      final idx = d.weekday % 7;
      if (idx >= 0 && idx < 7) counts[idx] += 1;
    }
    return List.generate(
      7,
      (i) => ChartDataPoint(label: _weekLabels[i], value: counts[i]),
    );
  }

  static List<ChartDataPoint> quotesSentThisWeek(List<SupplierQuote> quotes) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday % 7));
    final counts = List<double>.filled(7, 0);
    for (final q in quotes) {
      final d = q.createdAt;
      if (d.isBefore(start)) continue;
      final idx = d.weekday % 7;
      if (idx >= 0 && idx < 7) counts[idx] += 1;
    }
    return List.generate(
      7,
      (i) => ChartDataPoint(label: _weekLabels[i], value: counts[i]),
    );
  }

  static List<ChartDataPoint> latestRequestQuoteCompare(
    List<SupplierQuote> quotes,
    List<QuoteRequest> requests,
  ) {
    if (quotes.isEmpty) return const [];

    final byRequest = <String, List<SupplierQuote>>{};
    for (final q in quotes) {
      if (q.status != SupplierQuoteStatus.sent &&
          q.status != SupplierQuoteStatus.approved) {
        continue;
      }
      byRequest.putIfAbsent(q.quoteRequestId, () => []).add(q);
    }

    String? bestRequestId;
    var maxCount = 0;
    byRequest.forEach((id, list) {
      if (list.length > maxCount) {
        maxCount = list.length;
        bestRequestId = id;
      }
    });
    bestRequestId ??= quotes.first.quoteRequestId;

    final list = byRequest[bestRequestId] ?? [];
    list.sort((a, b) => a.displayTotal.compareTo(b.displayTotal));
    return list
        .take(5)
        .toList()
        .asMap()
        .entries
        .map(
          (e) => ChartDataPoint(
            label: 'הצעה ${e.key + 1}',
            value: e.value.displayTotal,
          ),
        )
        .toList();
  }

  static List<StatusSlice> customerOrdersByStatus(List<QuoteRequest> requests) {
    if (requests.isEmpty) return const [];

    int count(QuoteRequestStatus s) =>
        requests.where((r) => r.status == s).length;

    return [
      StatusSlice(
        label: 'נשלחו',
        value: count(QuoteRequestStatus.sent).toDouble(),
        color: AppTheme.navy,
      ),
      StatusSlice(
        label: 'הצעות',
        value: count(QuoteRequestStatus.quotesReceived).toDouble(),
        color: AppTheme.teal,
      ),
      StatusSlice(
        label: 'הוזמנו',
        value: count(QuoteRequestStatus.ordered).toDouble(),
        color: AppTheme.emerald,
      ),
      StatusSlice(
        label: 'בדרך',
        value: count(QuoteRequestStatus.shipped).toDouble(),
        color: AppTheme.emeraldLight,
      ),
      StatusSlice(
        label: 'הושלמו',
        value: count(QuoteRequestStatus.completed).toDouble(),
        color: AppTheme.navyLight,
      ),
    ].where((s) => s.value > 0).toList();
  }

  static List<StatusSlice> supplierWinRate(int winPercent) {
    final won = winPercent.clamp(0, 100).toDouble();
    final lost = (100 - won).toDouble();
    if (won == 0 && lost == 0) return const [];
    return [
      StatusSlice(label: 'זכיות', value: won, color: AppTheme.emerald),
      StatusSlice(label: 'אחר', value: lost, color: AppTheme.borderColor),
    ];
  }

  static List<StatusSlice> supplierOrdersByStatus({
    required int toFulfill,
    required int shipped,
    required int sent,
    required int rejected,
  }) {
    final slices = <StatusSlice>[
      if (toFulfill > 0)
        StatusSlice(
          label: 'לביצוע',
          value: toFulfill.toDouble(),
          color: AppTheme.amber,
        ),
      if (sent > 0)
        StatusSlice(
          label: 'הצעות פעילות',
          value: sent.toDouble(),
          color: AppTheme.teal,
        ),
      if (shipped > 0)
        StatusSlice(
          label: 'נשלחו',
          value: shipped.toDouble(),
          color: AppTheme.emerald,
        ),
      if (rejected > 0)
        StatusSlice(
          label: 'נדחו',
          value: rejected.toDouble(),
          color: AppTheme.navyLight,
        ),
    ];
    return slices;
  }

  static bool hasChartData(List<ChartDataPoint> points) =>
      points.any((p) => p.value > 0);

  static bool hasSliceData(List<StatusSlice> slices) =>
      slices.fold<double>(0, (s, e) => s + e.value) > 0;

  /// Average age in days of open sent quotes (customer).
  static int averageQuoteAgeDays(List<SupplierQuote> quotes) {
    final open = quotes.where((q) => q.status == SupplierQuoteStatus.sent);
    if (open.isEmpty) return 0;
    final now = DateTime.now();
    final total = open.fold<int>(
      0,
      (s, q) => s + now.difference(q.createdAt).inDays,
    );
    return (total / open.length).round();
  }

  /// Estimated savings: spread between min/max on comparable quotes.
  static double estimatedSavings(List<SupplierQuote> quotes) {
    final byRequest = <String, List<double>>{};
    for (final q in quotes) {
      if (q.status == SupplierQuoteStatus.sent ||
          q.status == SupplierQuoteStatus.approved) {
        byRequest
            .putIfAbsent(q.quoteRequestId, () => [])
            .add(q.displayTotal);
      }
    }
    var savings = 0.0;
    for (final prices in byRequest.values) {
      if (prices.length < 2) continue;
      prices.sort();
      savings += prices.last - prices.first;
    }
    return savings;
  }
}
