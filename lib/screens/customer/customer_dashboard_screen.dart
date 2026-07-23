import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/enterprise_providers.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../providers/dashboard_analytics_provider.dart';
import '../../providers/dashboard_tasks_provider.dart';
import '../../providers/delivery_providers.dart';
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
import '../../widgets/projects/dashboard_projects_section.dart';
import '../../widgets/projects/create_project_dialog.dart';
import '../../providers/project_providers.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/demo_scenario_panel.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../utils/dashboard_chart_data.dart';
import '../../utils/project_attention.dart';
import '../../widgets/app_fade_in.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/dashboard_insights_row.dart';
import '../../widgets/v2_stat_card.dart';
import '../../widgets/permissions/invitation_accept_section.dart';
import '../../widgets/contractor/pending_procurement_requests_section.dart';

import '../../widgets/status_chip.dart';
import '../../widgets/design_system/design_system.dart';
/// Customer / contractor operational dashboard.
///
/// Presentation rebuilt to mirror the Bonim reference "סקירת פעילות הרכש"
/// layout: overview header → quick actions → KPI cards → insights (charts) →
/// attention → project summary → recent activity. All data wiring is unchanged;
/// this only reorganizes existing shared widgets and the providers they read.
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
            tooltip: 'פרופיל',
            onPressed: () => openFromDashboard(context, '/profile'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () =>
            const LoadingView(message: HebrewStrings.loadingDashboard),
        error: (e, _) => ErrorMessage.fromError(
          e,
          onRetry: () => ref.invalidate(authSessionProvider),
        ),
        data: (user) {
          final quotes =
              ref.watch(customerReceivedQuotesProvider).valueOrNull ?? [];
          final savings = DashboardChartData.estimatedSavings(quotes);
          final avgAge = DashboardChartData.averageQuoteAgeDays(quotes);
          final requests = ref.watch(customerRequestsProvider).valueOrNull ?? [];
          final attention = buildContractorAttentionItems(
            requests,
            AppTheme.amber,
            AppTheme.danger,
            AppTheme.navy,
          ).take(6).toList();
          final deliverySummary = ref.watch(customerDeliverySummaryProvider);

          return DashboardScrollBody(
            children: [
              // ---- Overview header ----
              AppFadeIn(
                child: DashboardWelcomeBanner(
                  greetingLine: HebrewStrings.welcomeCustomer,
                  name: user?.fullName ?? '',
                  subtitle: user?.city,
                  compact: true,
                ),
              ),

              // ---- Contextual / gated banners ----
              const SizedBox(height: 8),
              const AppFadeIn(child: InvitationAcceptSection()),
              const SizedBox(height: 8),
              const AppFadeIn(child: PendingProcurementRequestsSection()),
              if (ref.watch(showAdminNavProvider)) ...[
                const SizedBox(height: 8),
                AppFadeIn(child: StatusChip.platformAdmin()),
                const SizedBox(height: 8),
                AppFadeIn(
                  child: DashboardTile(
                    title: HebrewStrings.adminConsoleTitle,
                    subtitle: 'סקירת משתמשים, פרויקטים ובקשות',
                    icon: Icons.admin_panel_settings_outlined,
                    accent: DashboardAccent.navy,
                    onTap: () => context.push('/admin'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const AppFadeIn(child: DemoModeBanner()),
              const SizedBox(height: 8),
              const AppFadeIn(child: DemoScenarioPanel()),

              // ---- Quick actions ----
              const SizedBox(height: 16),
              const DashboardSectionHeader(
                title: 'סקירת פעילות הרכש',
                subtitle: 'מבט-על על הפרויקטים, הבקשות וההזמנות שלך',
                icon: Icons.dashboard_customize_outlined,
                accentColor: AppTheme.navy,
              ),
              AppFadeIn(
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryButton.icon(
                        icon: Icons.request_quote_outlined,
                        label: 'בקשת הצעת מחיר חדשה',
                        expand: false,
                        onPressed: () => context.push('/catalog'),
                      ),
                    ),
                    if (ref.watch(canCreateProjectProvider)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SecondaryButton(
                          label: 'הוספת פרויקט',
                          icon: Icons.add_location_alt_outlined,
                          onPressed: () => _createProject(context, ref),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppFadeIn(
                child: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'צפייה בהזמנות פעילות',
                        icon: Icons.local_shipping_outlined,
                        onPressed: () =>
                            openFromDashboard(context, '/active-orders'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SecondaryButton(
                        label: 'בדיקת הצעות חדשות',
                        icon: Icons.mark_email_read_outlined,
                        onPressed: () =>
                            openFromDashboard(context, '/received-quotes'),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- KPI cards ----
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
              if (avgAge > 0 || savings > 0) ...[
                const SizedBox(height: 10),
                AppFadeIn(
                  delay: const Duration(milliseconds: 60),
                  child: DashboardInsightsRow(
                    items: [
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
              ],

              // ---- Insights / charts ----
              const SizedBox(height: 24),
              const AppFadeIn(
                delay: Duration(milliseconds: 120),
                child: CustomerDashboardCharts(),
              ),

              // ---- Attention ----
              if (attention.isNotEmpty) ...[
                const SizedBox(height: 24),
                const DashboardSectionHeader(
                  title: 'דורש את תשומת ליבך',
                  icon: Icons.priority_high_rounded,
                  accentColor: AppTheme.amber,
                ),
                for (final item in attention)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppFadeIn(
                      child: Card(
                        child: ListTile(
                          leading: Icon(item.icon, color: item.tone),
                          title: Text(item.title),
                          subtitle: Text(item.subtitle),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () =>
                              context.push('/compare-quotes/${item.requestId}'),
                        ),
                      ),
                    ),
                  ),
              ],

              // ---- Project summary ----
              const SizedBox(height: 24),
              const AppFadeIn(child: DashboardProjectsSection()),

              // ---- Recent activity ----
              if (tasks.isNotEmpty) ...[
                const SizedBox(height: 24),
                AppFadeIn(
                  delay: const Duration(milliseconds: 40),
                  child: DashboardTasksPanel(tasks: tasks),
                ),
              ],
              if (analytics.recentQuotes.isNotEmpty) ...[
                const SizedBox(height: 24),
                const DashboardSectionHeader(
                  title: 'פעילות אחרונה',
                  subtitle: 'הצעות מחיר שהתקבלו לאחרונה',
                  icon: Icons.receipt_long_outlined,
                  accentColor: AppTheme.teal,
                ),
                ...analytics.recentQuotes.take(3).map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppFadeIn(
                          child: AppListCard(
                            onTap: () => context.push(
                              '/quote-detail/${q.id}?requestId=${q.quoteRequestId}&from=dashboard',
                            ),
                            title: q.supplierName,
                            subtitle: currency.format(q.displayTotal),
                            meta: q.deliveryTime,
                            trailing: StatusChip.quote(q.status),
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
                    ),
              ],

              // ---- Continue working (secondary quick actions) ----
              const SizedBox(height: 24),
              const DashboardSectionHeader(
                title: 'המשך עבודה',
                subtitle: 'קטלוג, סל בקשת חומרים והשוואת הצעות',
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
                    context.push('/rfq-draft?from=dashboard');
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
                onTap: () => context.push('/rfq-draft?from=dashboard'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: 'משלוחים',
                subtitle: deliverySummary.active > 0
                    ? '${deliverySummary.active} משלוחים פעילים בכל הפרויקטים'
                    : 'מעקב אחר משלוחים בכל הפרויקטים',
                icon: Icons.local_shipping_outlined,
                accent: DashboardAccent.navy,
                badge: deliverySummary.delayed > 0
                    ? '${deliverySummary.delayed}'
                    : null,
                onTap: () => openFromDashboard(context, '/deliveries'),
              ),
              const SizedBox(height: 10),
              DashboardTile(
                title: 'אנליטיקה',
                subtitle: 'רכש לפי ספק, פרויקט וצינור בקשות',
                icon: Icons.insights_outlined,
                accent: DashboardAccent.amber,
                onTap: () => openFromDashboard(context, '/analytics'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createProject(BuildContext context, WidgetRef ref) async {
    final result = await CreateProjectDialog.show(context);
    if (result == null || !context.mounted) return;
    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref.read(projectRepositoryProvider).createProject(
            ownerUid: uid,
            name: result.name,
            location: result.location,
            cityOrArea: result.cityOrArea,
            notes: result.notes,
            managerName: result.managerName,
            managerPhone: result.managerPhone,
            startDate: result.startDate,
            estimatedCompletionDate: result.estimatedCompletionDate,
          );
      ref.invalidate(currentUserProjectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }
  }
}
