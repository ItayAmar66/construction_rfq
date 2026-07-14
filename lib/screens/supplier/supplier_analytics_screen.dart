import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_dashboard_charts.dart';
import '../../models/quote_status.dart';
import '../../providers/dashboard_analytics_provider.dart';
import '../../providers/providers.dart';
import '../../providers/supplier_hierarchy_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dashboard_chart_data.dart';
import '../../utils/supplier_hierarchy.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/dashboard/dashboard_charts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class SupplierAnalyticsScreen extends ConsumerStatefulWidget {
  const SupplierAnalyticsScreen({super.key});

  @override
  ConsumerState<SupplierAnalyticsScreen> createState() =>
      _SupplierAnalyticsScreenState();
}

class _SupplierAnalyticsScreenState
    extends ConsumerState<SupplierAnalyticsScreen> {
  String? _contractorKey;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(supplierAllRequestsProvider);
    final analytics = ref.watch(supplierDashboardAnalyticsProvider);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'אנליטיקה'),
      body: requestsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת נתונים',
          icon: Icons.error_outline,
        ),
        data: (_) {
          final groups = ref.watch(supplierContractorGroupsProvider);
          final sent = ref.watch(supplierSentQuotesProvider).valueOrNull ?? [];
          final toFulfill =
              ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
          final history =
              ref.watch(supplierOrderHistoryProvider).valueOrNull ?? [];
          final myQuotes = [...sent, ...toFulfill, ...history];

          final scopedGroups = _contractorKey == null
              ? groups
              : groups.where((g) => g.key == _contractorKey).toList();
          final scopedRequests =
              scopedGroups.expand((g) => g.requests).toList();
          final orders = supplierOrdersFor(scopedRequests, myQuotes);

          if (groups.isEmpty) {
            return const EmptyState(
              message: 'אין עדיין נתונים להצגה',
              icon: Icons.bar_chart_outlined,
            );
          }

          final byContractor = <String, double>{};
          final byProject = <String, double>{};
          for (final row in orders) {
            byContractor[row.request.customerName] =
                (byContractor[row.request.customerName] ?? 0) +
                    row.quote.displayTotal;
            final projectLabel =
                row.request.projectName ?? row.request.siteName ?? 'פרויקט';
            byProject[projectLabel] =
                (byProject[projectLabel] ?? 0) + row.quote.displayTotal;
          }
          final contractorPoints = (byContractor.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(6)
              .map((e) => ChartDataPoint(label: e.key, value: e.value))
              .toList();
          final projectPoints = (byProject.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(6)
              .map((e) => ChartDataPoint(label: e.key, value: e.value))
              .toList();

          final delayedCount = scopedRequests
              .where((r) => r.status == QuoteRequestStatus.receivedWithIssues)
              .length;
          final upcomingCount = scopedRequests
              .where((r) => r.status == QuoteRequestStatus.shipped)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _contractorKey,
                decoration: const InputDecoration(labelText: 'סינון לפי קבלן'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('כל הקבלנים')),
                  for (final g in groups)
                    DropdownMenuItem(value: g.key, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => _contractorKey = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'אחוז זכייה',
                      value: '${analytics.winRatePercent}%',
                      icon: Icons.emoji_events_outlined,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'משלוחים בדרך',
                      value: '$upcomingCount',
                      icon: Icons.local_shipping_outlined,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'חריגות במשלוח',
                      value: '$delayedCount',
                      icon: Icons.report_problem_outlined,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (DashboardChartData.hasChartData(contractorPoints))
                DashboardChartCard(
                  title: 'מכירות לפי קבלן',
                  subtitle: 'הזמנות מאושרות (₪)',
                  accentColor: AppTheme.navy,
                  child: DashboardBarChart(
                    points: contractorPoints,
                    barColor: AppTheme.navy,
                    formatValue: (v) => v >= 1000
                        ? '${(v / 1000).toStringAsFixed(0)}k'
                        : '${v.toInt()}',
                  ),
                ),
              if (DashboardChartData.hasChartData(projectPoints))
                DashboardChartCard(
                  title: 'מכירות לפי פרויקט',
                  subtitle: 'הזמנות מאושרות (₪)',
                  accentColor: AppTheme.amber,
                  child: DashboardBarChart(
                    points: projectPoints,
                    barColor: AppTheme.amber,
                    formatValue: (v) => v >= 1000
                        ? '${(v / 1000).toStringAsFixed(0)}k'
                        : '${v.toInt()}',
                  ),
                ),
              const SupplierDashboardCharts(),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
