import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/quote_status_badge.dart';

class SupplierOrdersToFulfillScreen extends ConsumerWidget {
  const SupplierOrdersToFulfillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(supplierOrdersToFulfillProvider);
    final ordersCount = ref.watch(supplierOrdersToFulfillCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref
            .read(quoteServiceProvider)
            .markSupplierOrdersToFulfillSeen(user.id);
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: HebrewStrings.ordersToFulfill,
          count: ordersCount,
        ),
        body: ordersAsync.when(
          loading: () => const LoadingView(),
          error: (_, __) =>
              const Center(child: Text(HebrewStrings.errorGeneric)),
          data: (orders) {
            if (orders.isEmpty) {
              return const EmptyState(
                message: 'אין הזמנות ממתינות לביצוע',
                icon: Icons.local_shipping_outlined,
              );
            }
            return DateGroupedListView<SupplierQuote>(
              items: orders,
              dateFor: (q) => q.createdAt,
              itemBuilder: (context, quote) => _OrderCard(
                quote: quote,
                dateFormat: dateFormat,
                onTap: () => context.push(
                  '/supplier/order/${quote.id}?requestId=${quote.quoteRequestId}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.quote,
    required this.dateFormat,
    required this.onTap,
  });

  final SupplierQuote quote;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final request =
        ref.watch(quoteRequestProvider(quote.quoteRequestId)).valueOrNull;
    final customerName = request?.customerName ?? 'לקוח';
    final isUnread = quote.isUnreadOrderBySupplier;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isUnread) ...[
                    const CountBadge(count: 1, compact: true),
                    const SizedBox(width: 6),
                  ],
                  QuoteStatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${HebrewStrings.requestDate}: ${dateFormat.format(quote.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${HebrewStrings.deliveryTime}: ${quote.deliveryTime}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '₪${quote.totalPrice.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_left),
                ],
              ),
              QuoteMatchSummaryChips(
                items: quote.items,
                requestItems: request?.items ?? const [],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
