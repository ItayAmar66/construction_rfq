import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/rfq_draft_provider.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../providers/dashboard_analytics_provider.dart';
import '../../providers/dashboard_tasks_provider.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dashboard_navigation.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/dashboard/dashboard_charts.dart';
import '../../widgets/dashboard/responsive_dashboard_layout.dart';
import '../../widgets/dashboard_section_header.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/dashboard_tasks_panel.dart';
import '../../widgets/dashboard_welcome_banner.dart';
import '../../widgets/catalog/catalog_selector_sheet.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/demo_scenario_panel.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';
import '../../utils/dashboard_chart_data.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/dashboard_insights_row.dart';
import '../../widgets/v2_stat_card.dart';

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final analytics = ref.watch(customerDashboardAnalyticsProvider);
    final tasks = ref.watch(customerDashboardTasksProvider);
    final draftCount = ref.watch(rfqDraftCountProvider);
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');

    return Scaffold(
      appBar: AppBar(
        title: const Text(HebrewStrings.home),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => openFromDashboard(context, '/profile'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const LoadingView(message: HebrewStrings.loadingDashboard),
        error: (e, _) => ErrorMessage.fromError(
              e,
              onRetry: () => ref.invalidate(authSessionProvider),
            ),
        data: (user) {
          final quotes =
              ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];
          final savings = DashboardChartData.estimatedSavings(quotes);
          final avgAge = DashboardChartData.averageQuoteAgeDays(quotes);

          return DashboardScrollBody(
            children: [
              AppFadeIn(
                child: DashboardWelcomeBanner(
                  greetingLine: HebrewStrings.welcomeCustomer,
                  name: user?.fullName ?? '',
                  subtitle: user?.city,
                ),
              ),
              const SizedBox(height: 12),
              const AppFadeIn(child: DemoModeBanner()),
              const SizedBox(height: 12),
              const AppFadeIn(child: DemoScenarioPanel()),
              const SizedBox(height: 16),
              AppFadeIn(
                delay: const Duration(milliseconds: 40),
                child: DashboardTasksPanel(tasks: tasks),
              ),
              const SizedBox(height: 16),
              AppFadeIn(
                delay: const Duration(milliseconds: 80),
                child: DashboardInsightsRow(
                  items: [
                    DashboardInsight(
                      label: 'הוצאה החודש',
                      value: currency.format(analytics.monthlySpending),
                      icon: Icons.payments_outlined,
                      color: AppTheme.teal,
                    ),
                    DashboardInsight(
                      label: 'בקשות פעילות',
                      value: '${analytics.activeRequests}',
                      icon: Icons.pending_actions_outlined,
                      color: AppTheme.navy,
                    ),
                    if (avgAge > 0)
                      DashboardInsight(
                        label: 'גיל ממוצע להצעה',
                        value: '$avgAge ימים',
                        icon: Icons.schedule_outlined,
                        color: AppTheme.amber,
                        hint: 'הצעות ממתינות',
                      ),
                    if (savings > 0)
                      DashboardInsight(
                        label: 'חיסכון פוטנציאלי',
                        value: formatInsightCurrency(savings),
                        icon: Icons.savings_outlined,
                        color: AppTheme.emerald,
                        hint: 'מהשוואות מחיר',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const DashboardSectionHeader(
                title: 'מדדים מרכזיים',
                subtitle: 'נתונים חיים מהמערכת',
                icon: Icons.speed_outlined,
                accentColor: AppTheme.navy,
              ),
              ResponsiveKpiGrid(
                children: [
                  V2StatCard(
                    label: 'סה״כ בקשות',
                    value: '${analytics.totalRequests}',
                    icon: Icons.assignment_outlined,
                    accent: DashboardAccent.navy,
                    onTap: () => openFromDashboard(context, '/my-requests'),
                  ),
                  V2StatCard(
                    label: 'בקשות פעילות',
                    value: '${analytics.activeRequests}',
                    icon: Icons.pending_actions_outlined,
                    accent: DashboardAccent.teal,
                    badge: analytics.unreadRequestUpdates > 0
                        ? '${analytics.unreadRequestUpdates}'
                        : null,
                    onTap: () => openFromDashboard(context, '/my-requests'),
                  ),
                  V2StatCard(
                    label: 'הצעות שהתקבלו',
                    value: '${analytics.receivedQuotesCount}',
                    icon: Icons.compare_arrows,
                    accent: DashboardAccent.emerald,
                    badge: analytics.unreadQuotes > 0
                        ? '${analytics.unreadQuotes}'
                        : null,
                    onTap: () => openFromDashboard(context, '/received-quotes'),
                  ),
                  V2StatCard(
                    label: 'הזמנות שאושרו',
                    value: '${analytics.approvedOrders}',
                    icon: Icons.check_circle_outline,
                    accent: DashboardAccent.navy,
                    onTap: () => openFromDashboard(context, '/active-orders'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ResponsiveFullWidthKpi(
                child: V2StatCard(
                  label: 'הוצאה חודשית',
                  value: currency.format(analytics.monthlySpending),
                  icon: Icons.payments_outlined,
                  accent: DashboardAccent.teal,
                  subtitle: 'הזמנות שאושרו החודש',
                  compact: true,
                ),
              ),
              const SizedBox(height: 24),
              const AppFadeIn(
                delay: Duration(milliseconds: 120),
                child: CustomerDashboardCharts(),
              ),
              const SizedBox(height: 32),
              const DashboardSectionHeader(
                title: 'פעולות מהירות',
                subtitle: 'הכנת בקשת חומרים והשוואת הצעות',
                icon: Icons.bolt_outlined,
                accentColor: AppTheme.emerald,
              ),
              DashboardTile(
                key: const Key('customer_catalog_rfq_entry'),
                title: HebrewStrings.openCatalogForRfq,
                subtitle: HebrewStrings.openCatalogForRfqHint,
                icon: Icons.manage_search_outlined,
                accent: DashboardAccent.teal,
                onTap: () async {
                  final draft = await CatalogSelectorSheet.show(context);
                  if (draft != null && context.mounted) {
                    ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
                    context.push('/cart?from=dashboard');
                  }
                },
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: HebrewStrings.rfqDraftTitle,
                subtitle: 'הוסף חומרים ושלח לספקים',
                icon: Icons.request_quote_outlined,
                accent: DashboardAccent.emerald,
                badge: draftCount > 0 ? '$draftCount' : null,
                onTap: () => context.push('/cart?from=dashboard'),
              ),
              if (analytics.recentQuotes.isNotEmpty) ...[
                const SizedBox(height: 32),
                const DashboardSectionHeader(
                  title: 'הצעות אחרונות',
                  icon: Icons.receipt_long_outlined,
                  accentColor: AppTheme.teal,
                ),
                const SizedBox(height: 6),
                ...analytics.recentQuotes.take(3).map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppListCard(
                          onTap: () => context.push(
                            '/quote-detail/${q.id}?requestId=${q.quoteRequestId}&from=dashboard',
                          ),
                          title: q.supplierName,
                          subtitle: currency.format(q.displayTotal),
                          meta: q.deliveryTime,
                          trailing: QuoteStatusBadge(status: q.status),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                AppTheme.teal.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.store_outlined,
                              size: 18,
                              color: AppTheme.teal,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}
