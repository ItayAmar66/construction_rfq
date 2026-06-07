import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/request_display_helpers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';

class SupplierOrdersHistoryScreen extends ConsumerWidget {
  const SupplierOrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(supplierOrderHistoryProvider);
    final historyCount = ref.watch(supplierOrderHistoryCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.ordersHistory,
        count: historyCount,
      ),
      body: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) =>
            const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              message: 'אין היסטוריית הזמנות עדיין',
              icon: Icons.history,
            );
          }
          return DateGroupedListView<SupplierQuote>(
            items: orders,
            dateFor: (q) => q.createdAt,
            itemBuilder: (context, quote) => _HistoryCard(
              quote: quote,
              dateFormat: dateFormat,
              onTap: () => context.push(
                '/supplier/order/${quote.id}?requestId=${quote.quoteRequestId}',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({
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
                children: [
                  Expanded(
                    child: Text(
                      request?.customerName ?? 'לקוח',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  QuoteStatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                RequestDisplayHelpers.sentQuoteSubtitle(
                  customerCity: request?.customerCity,
                  requestItems: request?.items ?? const [],
                  deliveryTime: quote.deliveryTime,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '₪${quote.totalPrice.toStringAsFixed(0)} · ${dateFormat.format(quote.createdAt)}',
                style: theme.textTheme.bodyMedium,
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
