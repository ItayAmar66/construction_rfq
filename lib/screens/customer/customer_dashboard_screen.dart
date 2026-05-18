import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/cart_provider.dart';
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
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/v2_stat_card.dart';

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final analytics = ref.watch(customerDashboardAnalyticsProvider);
    final tasks = ref.watch(customerDashboardTasksProvider);
    final cartCount = ref.watch(cartProvider).fold(0, (s, i) => s + i.quantity);
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
        loading: () => const LoadingView(),
        error: (e, _) => ErrorMessage.fromError(
              e,
              onRetry: () => ref.invalidate(authSessionProvider),
            ),
        data: (user) {
          return DashboardScrollBody(
            children: [
              DashboardWelcomeBanner(
                greetingLine: HebrewStrings.welcomeCustomer,
                name: user?.fullName ?? '',
                subtitle: user?.city,
              ),
              const SizedBox(height: 20),
              DashboardTasksPanel(tasks: tasks),
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
              const SizedBox(height: 32),
              const CustomerDashboardCharts(),
              const SizedBox(height: 32),
              const DashboardSectionHeader(
                title: 'פעולות מהירות',
                subtitle: 'גישה ישירה לתהליכים נפוצים',
                icon: Icons.bolt_outlined,
                accentColor: AppTheme.emerald,
              ),
              DashboardTile(
                title: HebrewStrings.catalog,
                subtitle: 'עיין בקטלוג חומרי הבנייה',
                icon: Icons.storefront_outlined,
                accent: DashboardAccent.teal,
                onTap: () => openFromDashboard(context, '/catalog'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: HebrewStrings.cart,
                subtitle: 'הכן ושלח בקשת הצעת מחיר',
                icon: Icons.request_quote_outlined,
                accent: DashboardAccent.emerald,
                badge: cartCount > 0 ? '$cartCount' : null,
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push(
                              '/quote-detail/${q.id}?requestId=${q.quoteRequestId}&from=dashboard',
                            ),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            child: Ink(
                              decoration: AppTheme.cardDecoration(elevation: 2),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppTheme.teal.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.store,
                                    size: 18,
                                    color: AppTheme.teal,
                                  ),
                                ),
                                title: Text(
                                  q.supplierName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  currency.format(q.displayTotal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                trailing: QuoteStatusBadge(status: q.status),
                              ),
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
