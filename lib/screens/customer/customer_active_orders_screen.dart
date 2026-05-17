import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/quote_request.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/status_chip.dart';

class CustomerActiveOrdersScreen extends ConsumerWidget {
  const CustomerActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(customerActiveOrdersProvider);
    final count = ref.watch(customerActiveOrdersCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        final ids =
            ref.read(customerActiveOrdersProvider).map((r) => r.id).toSet();
        if (ids.isEmpty) return;
        await ref.read(quoteServiceProvider).markCustomerRequestsStatusSeen(
              user.id,
              requestIds: ids,
            );
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: HebrewStrings.activeOrders,
          count: count,
        ),
        body: ref.watch(customerRequestsProvider).when(
              loading: () => const LoadingView(),
              error: (_, __) =>
                  const Center(child: Text(HebrewStrings.errorGeneric)),
              data: (_) {
                if (activeOrders.isEmpty) {
                  return const EmptyState(
                    message: 'אין הזמנות פעילות כרגע',
                    icon: Icons.local_shipping_outlined,
                  );
                }
                return DateGroupedListView<QuoteRequest>(
                  items: activeOrders,
                  dateFor: (r) => r.sortDate,
                  itemBuilder: (context, request) => _ActiveOrderCard(
                    request: request,
                    dateFormat: dateFormat,
                    onTap: () {
                      if (request.hasApprovedQuote) {
                        context.push(
                          '/quote-detail/${request.approvedQuoteId}?requestId=${request.id}',
                        );
                      } else {
                        context.push('/compare-quotes/${request.id}');
                      }
                    },
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.request,
    required this.dateFormat,
    required this.onTap,
  });

  final QuoteRequest request;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'בקשה ${request.id.substring(0, 8)}...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${HebrewStrings.requestDate}: ${dateFormat.format(request.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}
