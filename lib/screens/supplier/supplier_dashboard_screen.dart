import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_analytics_provider.dart';
import '../../providers/dashboard_tasks_provider.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/dashboard_navigation.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/dashboard/dashboard_charts.dart';
import '../../widgets/dashboard/responsive_dashboard_layout.dart';
import '../../widgets/dashboard_section_header.dart';
import '../../widgets/dashboard_tile.dart';
import '../../widgets/dashboard_tasks_panel.dart';
import '../../widgets/dashboard_welcome_banner.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/v2_stat_card.dart';

import '../../widgets/status_chip.dart';
import '../../widgets/design_system/design_system.dart';
/// Supplier operational dashboard.
///
/// Presentation rebuilt to mirror the Bonim reference supplier home: overview
/// header → quick actions → KPI cards → insights (charts) → attention →
/// supplier summary (new RFQs + orders to fulfill) → quick actions. Data wiring
/// is unchanged; the summary lists reuse the same `incoming` / `toFulfill`
/// providers already watched here.
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
            tooltip: 'פרופיל',
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
          final incoming = ref.watch(incomingRequestsProvider).valueOrNull ?? [];
          final toFulfill =
              ref.watch(supplierOrdersToFulfillProvider).valueOrNull ?? [];
          final deliverySummary = ref.watch(supplierDeliverySummaryProvider);
          final approvedOrders = toFulfill
              .where((q) => q.status == SupplierQuoteStatus.approved)
              .toList();
          final attentionRows = <_SupplierAttentionRow>[
            for (final r in incoming.take(5))
              _SupplierAttentionRow(
                icon: Icons.new_releases_outlined,
                title: 'בקשת מחיר חדשה — טרם הוגשה הצעה',
                subtitle: r.projectName ?? r.customerName,
                tone: AppTheme.amber,
                onTap: () => context.push(
                  r.isTender ? '/tender/${r.id}' : '/respond/${r.id}',
                ),
              ),
            for (final q in approvedOrders.take(5))
              _SupplierAttentionRow(
                icon: Icons.local_shipping_outlined,
                title: 'הזמנה ממתינה למשלוח',
                subtitle: 'זמן אספקה: ${q.deliveryTime}',
                tone: AppTheme.navy,
                onTap: () => context.push(
                  '/supplier/order/${q.id}?requestId=${q.quoteRequestId}',
                ),
              ),
          ];

          return DashboardScrollBody(
            children: [
              // ---- Overview header ----
              AppFadeIn(
                child: DashboardWelcomeBanner(
                  greetingLine: HebrewStrings.welcomeSupplier,
                  name: user?.fullName ?? '',
                  subtitle: user?.userType.label,
                  compact: true,
                ),
              ),

              // ---- Contextual / gated banners ----
              if (ref.watch(showAdminNavProvider)) ...[
                const SizedBox(height: 8),
                AppFadeIn(child: StatusChip.platformAdmin()),
                const SizedBox(height: 8),
                AppFadeIn(
                  child: DashboardTile(
                    title: HebrewStrings.adminConsoleTitle,
                    subtitle: 'סקירת מערכת',
                    icon: Icons.admin_panel_settings_outlined,
                    accent: DashboardAccent.navy,
                    onTap: () => openFromDashboard(context, '/admin'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const AppFadeIn(child: DemoModeBanner()),

              // ---- Quick actions ----
              const SizedBox(height: 16),
              const DashboardSectionHeader(
                title: 'סקירת הפעילות',
                subtitle: 'בקשות, הצעות והזמנות במבט אחד',
                icon: Icons.dashboard_customize_outlined,
                accentColor: AppTheme.navy,
              ),
              AppFadeIn(
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryButton.icon(
                        icon: Icons.inbox_outlined,
                        label: HebrewStrings.incomingRequests,
                        expand: false,
                        onPressed: () => openFromDashboard(context, '/incoming'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SecondaryButton(
                        label: 'קבלנים ופרויקטים',
                        icon: Icons.business_outlined,
                        onPressed: () => openFromDashboard(
                            context, '/supplier/contractors'),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- KPI cards ----
              const SizedBox(height: 24),
              const DashboardSectionHeader(
                title: 'מדדים מרכזיים',
                subtitle: 'ביצועים בזמן אמת',
                icon: Icons.speed_outlined,
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

              // ---- Insights / charts ----
              const SizedBox(height: 24),
              const AppFadeIn(
                delay: Duration(milliseconds: 120),
                child: SupplierDashboardCharts(),
              ),

              // ---- Attention ----
              if (attentionRows.isNotEmpty) ...[
                const SizedBox(height: 24),
                const DashboardSectionHeader(
                  title: 'דורש את תשומת ליבך',
                  icon: Icons.priority_high_rounded,
                  accentColor: AppTheme.amber,
                ),
                for (final row in attentionRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppFadeIn(
                      child: Card(
                        child: ListTile(
                          leading: Icon(row.icon, color: row.tone),
                          title: Text(row.title),
                          subtitle: row.subtitle.isNotEmpty
                              ? Text(row.subtitle)
                              : null,
                          trailing: const Icon(Icons.chevron_left),
                          onTap: row.onTap,
                        ),
                      ),
                    ),
                  ),
              ],

              // ---- Supplier summary: new RFQs ----
              if (incoming.isNotEmpty) ...[
                const SizedBox(height: 24),
                const DashboardSectionHeader(
                  title: 'בקשות חדשות להצעה',
                  subtitle: 'הזדמנויות פתוחות להגשת הצעה',
                  icon: Icons.inbox_outlined,
                  accentColor: AppTheme.teal,
                ),
                ...incoming.take(4).map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppFadeIn(
                          child: AppListCard(
                            onTap: () => context.push(
                              r.isTender ? '/tender/${r.id}' : '/respond/${r.id}',
                            ),
                            title: r.projectName ?? r.customerName,
                            subtitle: r.customerCity.isNotEmpty
                                ? '${r.customerName} · ${r.customerCity}'
                                : r.customerName,
                            meta: r.isTender
                                ? '${r.items.length} פריטים · מכרז'
                                : '${r.items.length} פריטים',
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppTheme.teal.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: AppTheme.teal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                if (incoming.length > 4)
                  DashboardTile(
                    title: 'לכל הבקשות הנכנסות',
                    subtitle: '${incoming.length} בקשות פתוחות',
                    icon: Icons.inbox_outlined,
                    accent: DashboardAccent.teal,
                    onTap: () => openFromDashboard(context, '/incoming'),
                  ),
              ],

              // ---- Supplier summary: orders to fulfill ----
              if (approvedOrders.isNotEmpty) ...[
                const SizedBox(height: 24),
                const DashboardSectionHeader(
                  title: HebrewStrings.ordersToFulfill,
                  subtitle: 'הזמנות שאושרו וממתינות לביצוע',
                  icon: Icons.local_shipping_outlined,
                  accentColor: AppTheme.emerald,
                ),
                ...approvedOrders.take(4).map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppFadeIn(
                          child: AppListCard(
                            onTap: () => context.push(
                              '/supplier/order/${q.id}?requestId=${q.quoteRequestId}',
                            ),
                            title: currency.format(q.displayTotal),
                            subtitle: 'זמן אספקה: ${q.deliveryTime}',
                            trailing: StatusChip.quote(q.status),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  AppTheme.emerald.withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: AppTheme.emerald,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],

              // ---- Open tasks ----
              if (tasks.isNotEmpty) ...[
                const SizedBox(height: 24),
                AppFadeIn(
                  delay: const Duration(milliseconds: 40),
                  child: DashboardTasksPanel(tasks: tasks),
                ),
              ],

              // ---- Quick actions (navigation) ----
              const SizedBox(height: 24),
              const DashboardSectionHeader(
                title: 'פעולות מהירות',
                subtitle: 'ניהול הצעות והזמנות',
                icon: Icons.bolt_outlined,
                accentColor: AppTheme.emerald,
              ),
              DashboardTile(
                title: 'הצעות ממתינות להחלטה',
                subtitle: 'ממתין להחלטת לקוח',
                icon: Icons.hourglass_top_outlined,
                accent: DashboardAccent.navy,
                onTap: () => openFromDashboard(context, '/sent-quotes'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: 'משלוחים',
                subtitle: 'מעקב אחר משלוחים וסימון כנשלחו',
                icon: Icons.local_shipping_outlined,
                accent: DashboardAccent.navy,
                badge: deliverySummary.delayed > 0
                    ? '${deliverySummary.delayed}'
                    : null,
                onTap: () => openFromDashboard(context, '/supplier/deliveries'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: HebrewStrings.ordersHistory,
                subtitle: 'הזמנות שנשלחו ללקוחות',
                icon: Icons.history,
                accent: DashboardAccent.navy,
                onTap: () =>
                    openFromDashboard(context, '/supplier/orders-history'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: 'אנליטיקה מלאה',
                subtitle: 'מכירות לפי קבלן ופרויקט',
                icon: Icons.insights_outlined,
                accent: DashboardAccent.amber,
                onTap: () => openFromDashboard(context, '/supplier/analytics'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SupplierAttentionRow {
  const _SupplierAttentionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;
}
