import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/delivery.dart';
import '../../models/enterprise/project.dart';
import '../../models/quote_status.dart';
import '../../providers/delivery_providers.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../repositories/audit_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/project_attention.dart';
import '../../utils/project_order_helpers.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/deliveries/delivery_detail_sheet.dart';
import '../../widgets/deliveries/delivery_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/permissions/audit_events_list.dart';
import '../../widgets/permissions/project_team_hierarchy_section.dart';
import '../../widgets/projects/dashboard_projects_section.dart';
import '../../widgets/projects/project_info_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/v2_stat_card.dart';
import '../../widgets/projects/project_status_chip.dart';

class ProjectWorkspaceScreen extends ConsumerWidget {
  const ProjectWorkspaceScreen({super.key, required this.projectId});

  final String projectId;

  Future<void> _completeProject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('סיים פרויקט'),
        content: const Text(
          'לסיים את הפרויקט? ניתן עדיין לצפות בהיסטוריה ובעלויות.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(HebrewStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('סיים פרויקט'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref.read(projectRepositoryProvider).completeProject(
            projectId: projectId,
            ownerUid: uid,
          );
      ref.invalidate(projectProvider(projectId));
      ref.invalidate(currentUserProjectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }
  }

  Future<void> _requestDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('מחק פרויקט'),
        content: const Text(
          'הפרויקט יימחק בעוד 24 שעות. ניתן לבטל את המחיקה במהלך היום הקרוב.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(HebrewStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('מחק פרויקט'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref.read(projectRepositoryProvider).requestProjectDeletion(
            projectId: projectId,
            ownerUid: uid,
          );
      ref.invalidate(projectProvider(projectId));
      ref.invalidate(currentUserProjectsProvider);
      ref.invalidate(deletionPendingProjectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }
  }

  Future<void> _cancelDeletion(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authSessionProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref.read(projectRepositoryProvider).cancelProjectDeletion(
            projectId: projectId,
            ownerUid: uid,
          );
      ref.invalidate(projectProvider(projectId));
      ref.invalidate(currentUserProjectsProvider);
      ref.invalidate(deletionPendingProjectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectProvider(projectId));
    final canComplete = ref.watch(canCompleteProjectProvider);
    final canDelete = ref.watch(canDeleteProjectProvider);

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'פרויקט',
        breadcrumbs: [
          BreadcrumbItem(HebrewStrings.projectsSection, onTap: () => context.go('/home')),
        ],
      ),
      body: projectAsync.when(
        loading: () => const LoadingView(message: 'טוען פרויקט...'),
        error: (_, __) => EmptyState(
          message: HebrewStrings.errorGeneric,
          icon: Icons.error_outline,
          actionLabel: 'חזרה',
          onAction: () => context.pop(),
        ),
        data: (project) {
          if (project == null) {
            return EmptyState(
              message: 'הפרויקט לא נמצא',
              icon: Icons.apartment_outlined,
              actionLabel: 'חזרה',
              onAction: () => context.pop(),
            );
          }

          return DefaultTabController(
            length: 6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _ProjectHeader(
                    project: project,
                    canComplete: canComplete,
                    canDelete: canDelete,
                    onNewRequest: () {
                      final blocked = ProjectOrderHelpers.blockedMessage(project);
                      if (blocked != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(blocked)),
                        );
                        return;
                      }
                      context.push(
                        ProjectOrderHelpers.catalogRouteForProject(project.id),
                      );
                    },
                    onComplete: () => _completeProject(context, ref),
                    onDelete: () => _requestDeletion(context, ref),
                    onCancelDelete: () => _cancelDeletion(context, ref),
                    onEdit: () =>
                        DashboardProjectsSection.editProject(context, ref, project),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: TabBar(
                    isScrollable: true,
                    labelColor: AppTheme.navy,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.amber,
                    tabs: const [
                      Tab(text: 'סקירה'),
                      Tab(text: 'בקשות'),
                      Tab(text: 'הצעות'),
                      Tab(text: 'הזמנות'),
                      Tab(text: 'משלוחים'),
                      Tab(text: 'פעילות'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(project: project),
                      _RfqsTab(projectId: projectId),
                      _QuotesTab(projectId: projectId),
                      _OrdersTab(projectId: projectId),
                      _DeliveriesTab(projectId: projectId),
                      _ActivityTab(projectId: projectId),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.canComplete,
    required this.canDelete,
    required this.onNewRequest,
    required this.onComplete,
    required this.onDelete,
    required this.onCancelDelete,
    required this.onEdit,
  });

  final Project project;
  final bool canComplete;
  final bool canDelete;
  final VoidCallback onNewRequest;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onCancelDelete;
  final VoidCallback onEdit;

  String _fmtDate(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy', 'he').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = project.deletionTimeRemaining;
    final canOrder = ProjectOrderHelpers.canStartNewOrder(project);
    final blockedMessage = ProjectOrderHelpers.blockedMessage(project);

    void onOrderPressed() {
      if (!canOrder) {
        final msg = blockedMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
        return;
      }
      onNewRequest();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (project.locationLine.isNotEmpty)
                        Text(
                          project.locationLine,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      if (project.managerName != null &&
                          project.managerName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'מנהל פרויקט: ${project.managerName}'
                            '${project.managerPhone != null && project.managerPhone!.isNotEmpty ? ' · ${project.managerPhone}' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                      if (project.startDate != null ||
                          project.estimatedCompletionDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'התחלה: ${_fmtDate(project.startDate)} · סיום משוער: ${_fmtDate(project.estimatedCompletionDate)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                ProjectStatusChip(project: project),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'עריכת פרויקט',
                  onPressed: onEdit,
                ),
              ],
            ),
            if (project.isDeletionPending) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'הפרויקט מתוזמן למחיקה',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (remaining != null)
                      Text(
                        'נותרו ${remaining.inHours} שעות ${remaining.inMinutes.remainder(60)} דקות',
                        style: const TextStyle(fontSize: 13),
                      ),
                    if (canDelete) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onCancelDelete,
                        child: const Text('בטל מחיקה'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOrderPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: canOrder
                          ? AppTheme.navy
                          : AppTheme.navy.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.navy.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text(
                      HebrewStrings.newProjectOrder,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (canComplete && !project.isCompleted && !project.isDeletionPending)
                  OutlinedButton(
                    onPressed: onComplete,
                    child: const Text('סיים פרויקט'),
                  ),
                if (canDelete && !project.isDeletionPending) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onDelete,
                    child: const Text('מחק פרויקט'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(projectProcurementSummaryProvider(project.id));
    final requests = ref.watch(projectRequestsProvider(project.id));
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final attention = buildContractorAttentionItems(
      requests,
      AppTheme.amber,
      AppTheme.danger,
      AppTheme.navy,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            V2StatCard(
              label: 'בקשות פתוחות',
              value: '${summary.openRequests}',
              icon: Icons.assignment_outlined,
              accent: DashboardAccent.teal,
              compact: true,
            ),
            V2StatCard(
              label: 'הצעות ממתינות',
              value: '${summary.pendingQuotes}',
              icon: Icons.hourglass_top_outlined,
              accent: DashboardAccent.navy,
              compact: true,
            ),
            V2StatCard(
              label: 'הזמנות פעילות',
              value: '${summary.approvedOrders}',
              icon: Icons.assignment_turned_in_outlined,
              accent: DashboardAccent.emerald,
              compact: true,
            ),
            V2StatCard(
              label: 'סה״כ עלות מאושרת',
              value: currency.format(summary.totalApprovedCost),
              icon: Icons.payments_outlined,
              accent: DashboardAccent.navy,
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProjectInfoCard(project: project),
        const SizedBox(height: 4),
        if (attention.isNotEmpty) ...[
          Text('דורש את תשומת ליבך',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in attention)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(item.icon, color: item.tone),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.push('/compare-quotes/${item.requestId}'),
              ),
            ),
          const SizedBox(height: 12),
        ],
        ProjectTeamHierarchySection(
          projectId: project.id,
          orgId: project.orgId,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'פעולות אחרונות בפרויקט',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                AuditEventsList(
                  eventsAsync: ref.watch(projectAuditEventsProvider(project.id)),
                  compact: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RfqsTab extends ConsumerWidget {
  const _RfqsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(projectRequestsProvider(projectId));
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    if (requests.isEmpty) {
      return const EmptyState(
        message: 'עדיין אין בקשות בפרויקט',
        icon: Icons.inbox_outlined,
        hint: 'התחילו בקשה חדשה לפרויקט',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppListCard(
              onTap: () => context.push('/compare-quotes/${request.id}'),
              title: request.projectName ?? request.customerName,
              subtitle: request.notes,
              meta: dateFormat.format(request.createdAt),
              trailing: StatusChip(status: request.status),
            ),
          ),
      ],
    );
  }
}

class _QuotesTab extends ConsumerWidget {
  const _QuotesTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(projectRequestsProvider(projectId));
    final requestIds = requests.map((r) => r.id).toSet();
    final requestLabelById = {
      for (final r in requests) r.id: r.projectName ?? r.customerName,
    };
    final quotesAsync = ref.watch(customerReceivedQuotesProvider);
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');

    return quotesAsync.when(
      loading: () => const LoadingView(),
      error: (_, __) => const EmptyState(
        message: HebrewStrings.errorGeneric,
        icon: Icons.error_outline,
      ),
      data: (quotes) {
        final projectQuotes =
            quotes.where((q) => requestIds.contains(q.quoteRequestId)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (projectQuotes.isEmpty) {
          return const EmptyState(
            message: 'עדיין לא התקבלו הצעות בפרויקט',
            icon: Icons.request_quote_outlined,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final quote in projectQuotes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.push(
                    '/quote-detail/${quote.id}?requestId=${quote.quoteRequestId}',
                  ),
                  title: Text(quote.supplierName),
                  subtitle: Text(
                    requestLabelById[quote.quoteRequestId] ?? '',
                  ),
                  trailing: Text(
                    currency.format(quote.displayTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(projectProcurementSummaryProvider(projectId));
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');

    if (summary.winners.isEmpty) {
      return const EmptyState(
        message: 'עדיין אין הזמנות מאושרות בפרויקט',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in summary.winners)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => context.push('/compare-quotes/${row.requestId}'),
              title: Text(row.requestLabel),
              subtitle: Text('ספק זוכה: ${row.supplierName} · ${row.status}'),
              trailing: Text(
                currency.format(row.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('סה״כ בפרויקט'),
            trailing: Text(
              currency.format(summary.totalApprovedCost),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveriesTab extends ConsumerWidget {
  const _DeliveriesTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(projectRequestsProvider(projectId));
    final deliveries = requests
        .where(Delivery.isDelivery)
        .map((r) => Delivery.fromRequest(r))
        .toList()
      ..sort(compareDeliveries);

    if (deliveries.isEmpty) {
      return const EmptyState(
        message: 'אין משלוחים בפרויקט',
        icon: Icons.local_shipping_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final d in deliveries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DeliveryCard(
              delivery: d,
              onTap: () => showDeliveryDetailSheet(
                context,
                delivery: d,
                openOrderLabel: d.request.statusAllowsReceiptConfirmation
                    ? 'אישור קבלה'
                    : 'צפייה בהזמנה',
                onOpenOrder: () => context.push(
                  d.request.statusAllowsReceiptConfirmation
                      ? '/shipment-receipt/${d.id}'
                      : '/compare-quotes/${d.id}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AuditEventsList(
          eventsAsync: ref.watch(projectAuditEventsProvider(projectId)),
          compact: false,
        ),
      ],
    );
  }
}
