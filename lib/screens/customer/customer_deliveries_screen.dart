import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_status.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/app_list_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_chip.dart';

/// Cross-project deliveries view — every RFQ currently shipped, awaiting
/// receipt confirmation, or reported with issues, regardless of project.
class CustomerDeliveriesScreen extends ConsumerWidget {
  const CustomerDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(customerRequestsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'משלוחים'),
      body: requestsAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const EmptyState(
          message: 'שגיאה בטעינת משלוחים',
          icon: Icons.error_outline,
        ),
        data: (requests) {
          final deliveries = requests
              .where((r) => const {
                    QuoteRequestStatus.shipped,
                    QuoteRequestStatus.pendingReceipt,
                    QuoteRequestStatus.receivedWithIssues,
                  }.contains(r.status))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final delayed = deliveries
              .where((r) => r.status == QuoteRequestStatus.receivedWithIssues)
              .toList();
          final upcoming = deliveries
              .where((r) => r.status != QuoteRequestStatus.receivedWithIssues)
              .toList();

          if (deliveries.isEmpty) {
            return const EmptyState(
              message: 'אין משלוחים פעילים כרגע',
              icon: Icons.local_shipping_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (delayed.isNotEmpty) ...[
                Text(
                  'משלוחים עם חריגות',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final r in delayed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppListCard(
                      onTap: () => context.push('/compare-quotes/${r.id}'),
                      title: r.projectName ?? r.customerName,
                      subtitle: 'התקבל עם חריגות — נדרשת בדיקה',
                      meta: dateFormat.format(r.createdAt),
                      trailing: StatusChip(status: r.status),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              Text(
                'משלוחים בדרך',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (upcoming.isEmpty)
                const EmptyState(
                  message: 'אין משלוחים בדרך כרגע',
                  icon: Icons.local_shipping_outlined,
                )
              else
                for (final r in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppListCard(
                      onTap: () => context.push('/compare-quotes/${r.id}'),
                      title: r.projectName ?? r.customerName,
                      subtitle: r.notes,
                      meta: dateFormat.format(r.createdAt),
                      trailing: StatusChip(status: r.status),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
