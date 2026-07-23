import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../models/user_type.dart';
import '../../providers/providers.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../utils/customer_quote_match_helpers.dart';
import '../../utils/supplier_quote_status.dart';
import '../../widgets/filterable_list_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/summary_widgets.dart';

class CustomerReceivedQuotesScreen extends ConsumerWidget {
  const CustomerReceivedQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(customerReceivedQuotesProvider);
    final quotesCount = ref.watch(customerReceivedQuotesCountProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');

    return MarkSeenOnOpen(
      onMarkSeen: (ref) async {
        final user = ref.read(authSessionProvider).valueOrNull?.profile;
        if (user == null) return;
        await ref
            .read(quoteServiceProvider)
            .markCustomerReceivedQuotesSeen(user.id);
      },
      child: Scaffold(
        appBar: SecondaryAppBar(
          title: HebrewStrings.receivedQuotes,
          count: quotesCount,
        ),
        body: quotesAsync.when(
          loading: () => const LoadingView(),
          error: (_, __) => const EmptyState(
            message: HebrewStrings.errorGeneric,
            icon: Icons.error_outline,
          ),
          data: (quotes) {
            if (quotes.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyQuotes,
                icon: Icons.compare_arrows,
                hint: 'לאחר שספקים ישלחו הצעות, הן יוצגו כאן',
                accentGradient: AppTheme.gradientBlue,
              );
            }
            return FilterableListView<SupplierQuote>(
              items: quotes,
              dateFor: (q) => q.createdAt,
              searchHint: HebrewStrings.searchQuotesHint,
              searchTextFor: _quoteSearchText,
              filters: _receivedQuoteFilters(),
              itemBuilder: (context, quote) => _ReceivedQuoteCard(
                quote: quote,
                dateFormat: dateFormat,
                onOpen: () => context.push(
                  '/quote-detail/${quote.id}?requestId=${quote.quoteRequestId}',
                ),
                onCompare: () =>
                    context.push('/compare-quotes/${quote.quoteRequestId}'),
              ),
            );
          },
        ),
      ),
    );
  }
}

List<ListFilter<SupplierQuote>> _receivedQuoteFilters() => [
      ListFilter<SupplierQuote>.all(),
      ListFilter<SupplierQuote>(
        label: HebrewStrings.filterPending,
        color: AppTheme.navy,
        test: (q) => q.status == SupplierQuoteStatus.sent,
      ),
      ListFilter<SupplierQuote>(
        label: HebrewStrings.filterApproved,
        color: AppTheme.emerald,
        test: (q) =>
            q.status == SupplierQuoteStatus.approved ||
            q.status == SupplierQuoteStatus.shipped,
      ),
      ListFilter<SupplierQuote>(
        label: HebrewStrings.filterRejected,
        color: AppTheme.amber,
        test: (q) =>
            q.status == SupplierQuoteStatus.rejected ||
            q.status == SupplierQuoteStatus.notSelected ||
            q.status == SupplierQuoteStatus.outdated,
      ),
    ];

String _quoteSearchText(SupplierQuote quote) => [
      quote.supplierName,
      UserType.fromString(quote.supplierType).label,
      SupplierQuoteStatus.label(quote.status),
    ].join(' ');

class _ReceivedQuoteCard extends ConsumerWidget {
  const _ReceivedQuoteCard({
    required this.quote,
    required this.dateFormat,
    required this.onOpen,
    required this.onCompare,
  });

  final SupplierQuote quote;
  final DateFormat dateFormat;
  final VoidCallback onOpen;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requestItems = ref
            .watch(quoteRequestProvider(quote.quoteRequestId))
            .valueOrNull
            ?.items ??
        const [];
    final hasAlternatives = quoteHasAlternativeItems(quote.items);
    final currency =
        NumberFormat.currency(locale: 'he_IL', symbol: '₪', decimalDigits: 0);
    final supplierTypeLabel = UserType.fromString(quote.supplierType).label;

    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EntityAvatar(name: quote.supplierName),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.supplierName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$supplierTypeLabel · ${dateFormat.format(quote.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  QuoteStatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              PrimaryTotalBox(
                caption: 'סה״כ כולל מע״מ ומשלוח',
                amount: currency.format(quote.displayTotal),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: InfoField(
                      label: HebrewStrings.deliveryTime,
                      value: quote.deliveryTime,
                      icon: Icons.schedule_outlined,
                    ),
                  ),
                  Expanded(
                    child: InfoField(
                      label: 'עלות משלוח',
                      value: quote.deliveryCost <= 0
                          ? 'חינם'
                          : currency.format(quote.deliveryCost),
                      icon: Icons.local_shipping_outlined,
                    ),
                  ),
                ],
              ),
              if (hasAlternatives)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _AlternativesNote(),
                ),
              const SizedBox(height: AppSpacing.xs),
              QuoteMatchSummaryChips(
                items: quote.items,
                requestItems: requestItems,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpen,
                      child: const Text(HebrewStrings.viewQuoteDetails),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      onPressed: onCompare,
                      child: const Text(HebrewStrings.compareQuotes),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlternativesNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF0DC),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 15, color: AppTheme.amberDark),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'כוללת פריטי חלופה — השווה לפני אישור',
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
