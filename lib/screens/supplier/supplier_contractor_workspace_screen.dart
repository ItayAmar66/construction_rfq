import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/supplier_hierarchy_providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/project_attention.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class SupplierContractorWorkspaceScreen extends ConsumerWidget {
  const SupplierContractorWorkspaceScreen({
    super.key,
    required this.contractorKey,
  });

  final String contractorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(supplierAllRequestsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'קבלן',
        breadcrumbs: [
          BreadcrumbItem('קבלנים', onTap: () => context.go('/supplier/contractors')),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת נתוני הקבלן',
          icon: Icons.error_outline,
        ),
        data: (_) {
          final group = ref.watch(supplierContractorGroupProvider(contractorKey));
          if (group == null) {
            return const EmptyState(
              message: 'הקבלן לא נמצא',
              icon: Icons.business_outlined,
            );
          }

          final attention = buildSupplierAttentionItems(
            group.requests,
            AppTheme.amber,
            AppTheme.danger,
            AppTheme.navy,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.navy.withValues(alpha: 0.1),
                        child: const Icon(Icons.business_outlined,
                            color: AppTheme.navy, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${group.activeProjectCount} פרויקטים · פעילות אחרונה: ${dateFormat.format(group.latestActivity)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (group.isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'קבלן חדש',
                            style: TextStyle(
                              color: AppTheme.amberDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (attention.isNotEmpty) ...[
                const SizedBox(height: 16),
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
                      onTap: () => context.push('/respond/${item.requestId}'),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text('פרויקטי בנייה', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (group.projects.isEmpty)
                const EmptyState(
                  message: 'עדיין אין פרויקטים לקבלן זה',
                  icon: Icons.apartment_outlined,
                )
              else
                for (final project in group.projects)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () =>
                          context.push('/supplier/projects/${project.projectId}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
                              child: const Icon(Icons.apartment_outlined,
                                  color: AppTheme.teal, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          project.projectName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      if (project.isNew)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.amber
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'פרויקט חדש',
                                            style: TextStyle(
                                              color: AppTheme.amberDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (project.projectLocation.isNotEmpty)
                                    Text(
                                      project.projectLocation,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_left,
                                color: AppTheme.textSecondary),
                          ],
                        ),
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
