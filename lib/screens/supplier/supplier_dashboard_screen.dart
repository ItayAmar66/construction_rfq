import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import '../../widgets/v2_stat_card.dart';

class SupplierDashboardScreen extends ConsumerWidget {
  const SupplierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final analytics = ref.watch(supplierDashboardAnalyticsProvider);
    final tasks = ref.watch(supplierDashboardTasksProvider);
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
                greetingLine: HebrewStrings.welcomeSupplier,
                name: user?.fullName ?? '',
                subtitle: user?.userType.label,
              ),
              const SizedBox(height: 20),
              DashboardTasksPanel(tasks: tasks),
              const SizedBox(height: 24),
              const DashboardSectionHeader(
                title: 'מדדים מרכזיים',
                subtitle: 'ביצועים בזמן אמת',
                icon: Icons.analytics_outlined,
                accentColor: AppTheme.navy,
              ),
              ResponsiveKpiGrid(
                children: [
                  V2StatCard(
                    label: 'בקשות נכנסות',
                    value: '${analytics.incomingCount}',
                    icon: Icons.inbox_outlined,
                    accent: DashboardAccent.teal,
                    badge: analytics.unseenIncoming > 0
                        ? '${analytics.unseenIncoming}'
                        : null,
                    onTap: () => openFromDashboard(context, '/incoming'),
                  ),
                  V2StatCard(
                    label: 'הצעות שנשלחו',
                    value: '${analytics.sentQuotesCount}',
                    icon: Icons.send_outlined,
                    accent: DashboardAccent.navy,
                    onTap: () => openFromDashboard(context, '/sent-quotes'),
                  ),
                  V2StatCard(
                    label: 'הזמנות שאושרו',
                    value: '${analytics.approvedOrders}',
                    icon: Icons.assignment_turned_in_outlined,
                    accent: DashboardAccent.emerald,
                    onTap: () => openFromDashboard(context, '/supplier/orders'),
                  ),
                  V2StatCard(
                    label: 'בביצוע',
                    value: '${analytics.ordersInProgress}',
                    icon: Icons.local_shipping_outlined,
                    accent: DashboardAccent.teal,
                    badge: analytics.unreadOrders > 0
                        ? '${analytics.unreadOrders}'
                        : null,
                    onTap: () => openFromDashboard(context, '/supplier/orders'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ResponsiveKpiRow(
                children: [
                  V2StatCard(
                    label: 'הכנסה חודשית',
                    value: currency.format(analytics.monthlyRevenue),
                    icon: Icons.trending_up,
                    accent: DashboardAccent.navy,
                    subtitle: 'הזמנות שנשלחו',
                    compact: true,
                  ),
                  V2StatCard(
                    label: 'אחוז זכייה',
                    value: '${analytics.winRatePercent}%',
                    icon: Icons.emoji_events_outlined,
                    accent: DashboardAccent.emerald,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const SupplierDashboardCharts(),
              const SizedBox(height: 32),
              const DashboardSectionHeader(
                title: 'פעולות מהירות',
                subtitle: 'ניהול הצעות והזמנות',
                icon: Icons.bolt_outlined,
                accentColor: AppTheme.emerald,
              ),
              DashboardTile(
                title: HebrewStrings.incomingRequests,
                subtitle: 'בקשות הצעת מחיר מלקוחות',
                icon: Icons.inbox_outlined,
                accent: DashboardAccent.teal,
                count: analytics.unseenIncoming,
                onTap: () => openFromDashboard(context, '/incoming'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: HebrewStrings.ordersToFulfill,
                subtitle: 'הזמנות שאושרו על ידי לקוחות',
                icon: Icons.assignment_turned_in_outlined,
                accent: DashboardAccent.emerald,
                count: analytics.unreadOrders,
                onTap: () => openFromDashboard(context, '/supplier/orders'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: HebrewStrings.ordersHistory,
                subtitle: 'הזמנות שנשלחו ללקוחות',
                icon: Icons.history,
                accent: DashboardAccent.navy,
                onTap: () => openFromDashboard(context, '/supplier/orders-history'),
              ),
            ],
          );
        },
      ),
    );
  }
}
