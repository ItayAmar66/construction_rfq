import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/request_display_helpers.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/app_async_body.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/catalog/supplier_quote_items_section.dart';
import '../../widgets/projects/project_context_chip.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/filterable_list_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/summary_widgets.dart';

import '../../widgets/status_chip.dart';
class SentQuotesScreen extends ConsumerWidget {
  const SentQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(supplierSentQuotesProvider);
    final sentCount = ref.watch(supplierSentQuotesCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');

    return Scaffold(
      appBar: SecondaryAppBar(
        title: HebrewStrings.sentQuotes,
        count: sentCount,
      ),
      body: quotesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => AppErrorCenter(
          message: HebrewStrings.errorLoadSentQuotes,
          onRetry: () => ref.invalidate(supplierSentQuotesProvider),
        ),
        data: (quotes) {
          if (quotes.isEmpty) {
            return const EmptyState(
              message: HebrewStrings.emptySentQuotes,
              icon: Icons.send_outlined,
              hint: HebrewStrings.emptySentQuotesHint,
            );
          }
          return FilterableListView<SupplierQuote>(
            items: quotes,
            dateFor: (q) => q.createdAt,
            filters: _sentQuoteFilters(),
            itemBuilder: (context, quote) {
              return Consumer(
                builder: (context, ref, _) {
                  final request = ref
                      .watch(quoteRequestProvider(quote.quoteRequestId))
                      .valueOrNull;
                  final requestItems = request?.items ?? const [];
                  final currency = NumberFormat.currency(
                    locale: 'he_IL',
                    symbol: '₪',
                    decimalDigits: 0,
                  );
                  final customerName = request?.customerName ?? '';
                  final title = RequestDisplayHelpers.sentQuoteTitle(
                    customerName: request?.customerName,
                    customerCity: request?.customerCity,
                    requestItems: requestItems,
                  );
                  final subtitle = RequestDisplayHelpers.sentQuoteSubtitle(
                    customerCity: request?.customerCity,
                    requestItems: requestItems,
                    deliveryTime: quote.deliveryTime,
                  );
                  return Container(
                    decoration: AppTheme.cardDecoration(),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        leading: EntityAvatar(
                          name: customerName,
                          color: AppTheme.navy,
                          size: 42,
                        ),
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            StatusChip.quote(quote.status),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            if (quote.isOutdated)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: _OutdatedNote(),
                              ),
                            Row(
                              children: [
                                Text(
                                  currency.format(quote.displayTotal),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dateFormat.format(quote.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            if (request != null)
                              ProjectContextChip(request: request),
                            QuoteMatchSummaryChips(
                              items: quote.items,
                              requestItems: requestItems,
                            ),
                          ],
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        children: [
                          SupplierQuoteItemsSection(
                            quote: quote,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

List<ListFilter<SupplierQuote>> _sentQuoteFilters() => [
      ListFilter<SupplierQuote>.all(),
      ListFilter<SupplierQuote>(
        label: HebrewStrings.filterPending,
        color: AppTheme.navy,
        test: (q) =>
            q.status == SupplierQuoteStatus.sent ||
            q.status == SupplierQuoteStatus.pendingCustomer,
      ),
      ListFilter<SupplierQuote>(
        label: HebrewStrings.filterApproved,
        color: AppTheme.emerald,
        test: (q) =>
            q.status == SupplierQuoteStatus.approved ||
            q.status == SupplierQuoteStatus.won ||
            q.status == SupplierQuoteStatus.shipped ||
            q.status == SupplierQuoteStatus.delivered,
      ),
      ListFilter<SupplierQuote>(
        label: HebrewStrings.filterRejected,
        color: AppTheme.amber,
        test: (q) =>
            q.status == SupplierQuoteStatus.rejected ||
            q.status == SupplierQuoteStatus.lost ||
            q.status == SupplierQuoteStatus.notSelected ||
            q.status == SupplierQuoteStatus.outdated,
      ),
    ];

class _OutdatedNote extends StatelessWidget {
  const _OutdatedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF0DC),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_toggle_off,
              size: 14, color: AppTheme.amberDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'הלקוח עדכן את הבקשה לאחר שליחת ההצעה',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.amberDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
