import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enterprise/project.dart';
import '../../providers/enterprise_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/project_order_helpers.dart';
import '../../utils/user_facing_error.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/permissions/project_team_hierarchy_section.dart';
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
    final summary = ref.watch(projectProcurementSummaryProvider(projectId));
    final requests = ref.watch(projectRequestsProvider(projectId));
    final canComplete = ref.watch(canCompleteProjectProvider);
    final canDelete = ref.watch(canDeleteProjectProvider);
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Scaffold(
      appBar: SecondaryAppBar(title: 'פרויקט'),
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProjectHeader(
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
              ),
              const SizedBox(height: 16),
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
                    label: 'הזמנות מאושרות',
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
              ProjectTeamHierarchySection(
                projectId: projectId,
                orgId: project.orgId,
              ),
              const SizedBox(height: 20),
              Text(
                'בקשות בפרויקט',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (requests.isEmpty)
                const EmptyState(
                  message: 'עדיין אין בקשות בפרויקט',
                  icon: Icons.inbox_outlined,
                  hint: 'התחילו בקשה חדשה לפרויקט',
                )
              else
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
              const SizedBox(height: 20),
              Text(
                'הזמנות בפרויקט',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (summary.winners.isEmpty)
                const EmptyState(
                  message: 'עדיין אין הזמנות מאושרות בפרויקט',
                  icon: Icons.receipt_long_outlined,
                )
              else
                for (final row in summary.winners)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(row.requestLabel),
                      subtitle: Text(
                        'ספק זוכה: ${row.supplierName} · ${row.status}',
                      ),
                      trailing: Text(currency.format(row.totalAmount)),
                    ),
                  ),
              const SizedBox(height: 20),
              Text(
                'עלות מאושרת',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
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
  });

  final Project project;
  final bool canComplete;
  final bool canDelete;
  final VoidCallback onNewRequest;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onCancelDelete;

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
                    ],
                  ),
                ),
                ProjectStatusChip(project: project),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOrderPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: canOrder
                      ? AppTheme.navy
                      : AppTheme.navy.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.navy.withValues(alpha: 0.35),
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canComplete && !project.isCompleted && !project.isDeletionPending)
                  OutlinedButton(
                    onPressed: onComplete,
                    child: const Text('סיים פרויקט'),
                  ),
                if (canDelete && !project.isDeletionPending)
                  OutlinedButton(
                    onPressed: onDelete,
                    child: const Text('מחק פרויקט'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
