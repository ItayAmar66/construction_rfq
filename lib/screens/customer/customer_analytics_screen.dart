import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote_status.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dashboard_chart_data.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/dashboard/dashboard_charts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class CustomerAnalyticsScreen extends ConsumerStatefulWidget {
  const CustomerAnalyticsScreen({super.key});

  @override
  ConsumerState<CustomerAnalyticsScreen> createState() =>
      _CustomerAnalyticsScreenState();
}

class _CustomerAnalyticsScreenState
    extends ConsumerState<CustomerAnalyticsScreen> {
  String? _projectId;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(customerRequestsProvider);
    final quotesAsync = ref.watch(customerReceivedQuotesProvider);
    final projects = ref.watch(currentUserProjectsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'אנליטיקה'),
      body: requestsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת נתונים',
          icon: Icons.error_outline,
        ),
        data: (allRequests) {
          final quotes = quotesAsync.valueOrNull ?? [];
          final requests = _projectId == null
              ? allRequests
              : allRequests.where((r) => r.projectId == _projectId).toList();
          final requestIds = requests.map((r) => r.id).toSet();
          final scopedQuotes = _projectId == null
              ? quotes
              : quotes.where((q) => requestIds.contains(q.quoteRequestId)).toList();

          final funnel = DashboardChartData.rfqFunnel(requests);
          final bySupplier = DashboardChartData.spendBySupplier(scopedQuotes);
          final delayed = requests
              .where((r) => r.status == QuoteRequestStatus.receivedWithIssues)
              .toList();
          final upcoming = requests
              .where((r) => r.status == QuoteRequestStatus.shipped)
              .toList();

          if (requests.isEmpty && projects.isEmpty) {
            return const EmptyState(
              message: 'אין עדיין נתונים להצגה',
              icon: Icons.bar_chart_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'סינון לפי פרויקט'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('כל הפרויקטים')),
                  for (final p in projects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _projectId = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'משלוחים בדרך',
                      value: '${upcoming.length}',
                      icon: Icons.local_shipping_outlined,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'משלוחים באיחור/חריגה',
                      value: '${delayed.length}',
                      icon: Icons.report_problem_outlined,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (DashboardChartData.hasChartData(funnel))
                DashboardChartCard(
                  title: 'צינור בקשות להזמנה',
                  subtitle: 'מבקשה ועד הזמנה מאושרת',
                  accentColor: AppTheme.navy,
                  child: DashboardBarChart(points: funnel, barColor: AppTheme.navy),
                ),
              if (DashboardChartData.hasChartData(bySupplier))
                DashboardChartCard(
                  title: 'רכש לפי ספק',
                  subtitle: 'הזמנות מאושרות (₪)',
                  accentColor: AppTheme.teal,
                  child: DashboardBarChart(
                    points: bySupplier,
                    barColor: AppTheme.teal,
                    formatValue: (v) => v >= 1000
                        ? '${(v / 1000).toStringAsFixed(0)}k'
                        : '${v.toInt()}',
                  ),
                ),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
