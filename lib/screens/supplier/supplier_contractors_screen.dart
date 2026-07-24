import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/supplier_hierarchy_providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/design_system/design_system.dart';

class SupplierContractorsScreen extends ConsumerWidget {
  const SupplierContractorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(supplierAllRequestsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'קבלנים'),
      body: groupsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת הקבלנים',
          icon: Icons.error_outline,
        ),
        data: (_) {
          final groups = ref.watch(supplierContractorGroupsProvider);
          if (groups.isEmpty) {
            return const EmptyState(
              message: 'עדיין אין קבלנים פעילים',
              icon: Icons.groups_outlined,
              hint: 'קבלנים יופיעו כאן לאחר קבלת בקשת מחיר ראשונה',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push('/supplier/contractors/${g.key}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.navy.withValues(alpha: 0.1),
                          child: const Icon(Icons.business_outlined,
                              color: AppTheme.navy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      g.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (g.isNew)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.amber.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'קבלן חדש',
                                        style: TextStyle(
                                          color: AppTheme.amberDark,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${g.activeProjectCount} פרויקטים · פעילות אחרונה: ${dateFormat.format(g.latestActivity)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (g.newRfqCount > 0)
                          StatusChip(
                            label: '${g.newRfqCount} בקשות חדשות',
                            foreground: AppTheme.teal,
                            background: AppTheme.teal.withValues(alpha: 0.12),
                            bordered: false,
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
