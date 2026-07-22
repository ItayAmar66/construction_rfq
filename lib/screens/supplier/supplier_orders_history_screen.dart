import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/request_display_helpers.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/summary_widgets.dart';

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
        error: (_, __) => const EmptyState(
          message: HebrewStrings.errorGeneric,
          icon: Icons.error_outline,
        ),
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
    final currency =
        NumberFormat.currency(locale: 'he_IL', symbol: '₪', decimalDigits: 0);

    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EntityAvatar(
                    name: '',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.emerald,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request?.customerName ?? 'לקוח',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${RequestDisplayHelpers.sentQuoteSubtitle(
                            customerCity: request?.customerCity,
                            requestItems: request?.items ?? const [],
                            deliveryTime: quote.deliveryTime,
                          )} · ${dateFormat.format(quote.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(quote.displayTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      QuoteStatusBadge(status: quote.status),
                    ],
                  ),
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
