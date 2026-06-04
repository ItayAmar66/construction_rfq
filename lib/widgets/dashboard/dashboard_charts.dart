import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_dashboard_charts.dart';
import '../../providers/dashboard_analytics_provider.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dashboard_chart_data.dart';
import '../../utils/supplier_quote_status.dart';
import '../dashboard_section_header.dart';
import '../empty_state.dart';
import 'responsive_dashboard_layout.dart';

/// Card wrapper for dashboard chart sections (RTL).
class DashboardChartCard extends StatelessWidget {
  const DashboardChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.badge,
    this.usePieHeight = false,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final Widget child;
  final bool usePieHeight;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics =
            DashboardLayoutMetrics.fromWidth(constraints.maxWidth);
        final plotHeight = usePieHeight
            ? metrics.pieChartHeight
            : metrics.chartPlotHeight;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: AppTheme.cardDecoration(elevation: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.amber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.amber,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: plotHeight,
                width: double.infinity,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Vertical bar chart for time series (RTL labels).
class DashboardBarChart extends StatelessWidget {
  const DashboardBarChart({
    super.key,
    required this.points,
    this.barColor,
    this.formatValue,
  });

  final List<ChartDataPoint> points;
  final Color? barColor;
  final String Function(double)? formatValue;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('אין נתונים'));
    }

    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final color = barColor ?? AppTheme.primaryColor;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.borderColor,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                _formatAxis(v),
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (i, _) {
                final idx = i.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[idx].label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                  BarChartRodData(
                    toY: points[i].value,
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatAxis(double v) {
    if (formatValue != null) return formatValue!(v);
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

/// Line chart for monthly trends.
class DashboardLineChart extends StatelessWidget {
  const DashboardLineChart({
    super.key,
    required this.points,
    this.lineColor,
  });

  final List<ChartDataPoint> points;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('אין נתונים'));

    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final color = lineColor ?? AppTheme.primaryColor;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.borderColor,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : '${v.toInt()}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (i, _) {
                final idx = i.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[idx].label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            color: color,
            barWidth: 4,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie / donut chart for status breakdown.
class DashboardPieChart extends StatelessWidget {
  const DashboardPieChart({
    super.key,
    required this.slices,
    this.centerLabel,
  });

  final List<StatusSlice> slices;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return const Center(child: Text('אין נתונים'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxHeight;
        final sectionRadius = (size * 0.18).clamp(28.0, 42.0);
        final centerRadius = centerLabel != null
            ? (size * 0.14).clamp(22.0, 32.0)
            : (size * 0.10).clamp(18.0, 26.0);

        return Row(
          children: [
            Expanded(
              flex: 3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: centerRadius,
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.value,
                        color: slice.color,
                        radius: sectionRadius,
                        title: '${((slice.value / total) * 100).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (centerLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        centerLabel!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  for (final slice in slices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: slice.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              slice.label,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            slice.value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({this.hint = 'אין מספיק נתונים עדיין'});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        hint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Customer dashboard charts from live Firestore/demo data.
class CustomerDashboardCharts extends ConsumerWidget {
  const CustomerDashboardCharts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
    final quotes = ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];

    final monthly = DashboardChartData.lastSixMonthsSpend(
      quotes.where((q) => q.status == SupplierQuoteStatus.approved).toList(),
    );
    final week = DashboardChartData.requestsThisWeek(requests);
    final compare = DashboardChartData.latestRequestQuoteCompare(quotes, requests);
    final statusSlices = DashboardChartData.customerOrdersByStatus(requests);

    if (requests.isEmpty && quotes.isEmpty) {
      return const EmptyState(
        message: 'אין עדיין נתונים לגרפים',
        hint: 'שלחו בקשה ראשונה כדי לראות תובנות',
        icon: Icons.bar_chart_outlined,
        accentGradient: AppTheme.gradientNavy,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionHeader(
          title: 'תובנות',
          subtitle: 'מבוסס על הבקשות וההצעות שלכם',
          icon: Icons.bar_chart_rounded,
          accentColor: AppTheme.navy,
        ),
        DashboardChartCard(
          title: 'הוצאה חודשית',
          subtitle: '6 חודשים אחרונים (₪)',
          accentColor: AppTheme.navy,
          child: DashboardChartData.hasChartData(monthly)
              ? DashboardLineChart(points: monthly, lineColor: AppTheme.teal)
              : const _ChartEmpty(),
        ),
        DashboardChartCard(
          title: 'בקשות השבוע',
          subtitle: 'לפי יום',
          accentColor: AppTheme.teal,
          child: DashboardChartData.hasChartData(week)
              ? DashboardBarChart(points: week, barColor: AppTheme.teal)
              : const _ChartEmpty(),
        ),
        if (compare.isNotEmpty)
          DashboardChartCard(
            title: 'השוואת הצעות',
            subtitle: 'בקשה עם הכי הרבה הצעות',
            accentColor: AppTheme.emerald,
            child: DashboardBarChart(
              points: compare,
              barColor: AppTheme.emerald,
              formatValue: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : '${v.toInt()}',
            ),
          ),
        if (DashboardChartData.hasSliceData(statusSlices))
          DashboardChartCard(
            title: 'בקשות לפי סטטוס',
            usePieHeight: true,
            accentColor: AppTheme.navy,
            child: DashboardPieChart(
              slices: statusSlices,
              centerLabel: '${requests.length}',
            ),
          ),
      ],
    );
  }
}

/// Supplier dashboard charts from live data.
class SupplierDashboardCharts extends ConsumerWidget {
  const SupplierDashboardCharts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(supplierDashboardAnalyticsProvider);
    final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];
    final toFulfill = ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
    final history = ref.watch(supplierOrderHistoryProvider).valueOrNull ?? [];

    final revenue = DashboardChartData.lastSixMonthsSpend(
      [...toFulfill, ...history]
          .where(
            (q) =>
                q.status == SupplierQuoteStatus.approved ||
                q.status == SupplierQuoteStatus.shipped,
          )
          .toList(),
    );
    final week = DashboardChartData.quotesSentThisWeek(sent);
    final winSlices =
        DashboardChartData.supplierWinRate(analytics.winRatePercent);
    final orderSlices = DashboardChartData.supplierOrdersByStatus(
      toFulfill: toFulfill.length,
      shipped: history
          .where((q) => q.status == SupplierQuoteStatus.shipped)
          .length,
      sent: sent.where((q) => !q.isOutdated).length,
      rejected: history
          .where((q) => q.status == SupplierQuoteStatus.rejected)
          .length,
    );

    if (sent.isEmpty && toFulfill.isEmpty && history.isEmpty) {
      return const EmptyState(
        message: 'אין עדיין נתונים לגרפים',
        hint: 'הגישו הצעות כדי לראות ביצועים',
        icon: Icons.show_chart_outlined,
        accentGradient: AppTheme.gradientTeal,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashboardSectionHeader(
          title: 'תובנות',
          subtitle: 'מבוסס על ההצעות וההזמנות שלכם',
          icon: Icons.show_chart_outlined,
          accentColor: AppTheme.navy,
        ),
        DashboardChartCard(
          title: 'הכנסה חודשית',
          subtitle: '6 חודשים אחרונים (₪)',
          accentColor: AppTheme.navy,
          child: DashboardChartData.hasChartData(revenue)
              ? DashboardLineChart(points: revenue, lineColor: AppTheme.teal)
              : const _ChartEmpty(),
        ),
        DashboardChartCard(
          title: 'הצעות שנשלחו',
          subtitle: 'שבוע נוכחי',
          accentColor: AppTheme.teal,
          child: DashboardChartData.hasChartData(week)
              ? DashboardBarChart(points: week, barColor: AppTheme.teal)
              : const _ChartEmpty(),
        ),
        if (DashboardChartData.hasSliceData(winSlices))
          DashboardChartCard(
            title: 'אחוז זכייה',
            usePieHeight: true,
            accentColor: AppTheme.emerald,
            child: DashboardPieChart(
              slices: winSlices,
              centerLabel: '${analytics.winRatePercent}%',
            ),
          ),
        if (DashboardChartData.hasSliceData(orderSlices))
          DashboardChartCard(
            title: 'צינור הזמנות',
            usePieHeight: true,
            accentColor: AppTheme.navy,
            child: DashboardPieChart(slices: orderSlices),
          ),
      ],
    );
  }
}
