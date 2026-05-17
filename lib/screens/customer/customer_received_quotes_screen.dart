import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/mark_seen_on_open.dart';
import '../../widgets/quote_status_badge.dart';

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
          error: (_, __) =>
              const Center(child: Text(HebrewStrings.errorGeneric)),
          data: (quotes) {
            if (quotes.isEmpty) {
              return const EmptyState(
                message: HebrewStrings.emptyQuotes,
                icon: Icons.compare_arrows,
                hint: 'לאחר שספקים ישלחו הצעות, הן יוצגו כאן',
                accentGradient: AppTheme.gradientBlue,
              );
            }
            return DateGroupedListView<SupplierQuote>(
              items: quotes,
              dateFor: (q) => q.createdAt,
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

class _ReceivedQuoteCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.supplierName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${HebrewStrings.deliveryTime}: ${quote.deliveryTime}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(quote.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      QuoteStatusBadge(status: quote.status),
                      const SizedBox(height: 8),
                      Text(
                        '₪${quote.totalPrice.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(HebrewStrings.viewQuoteDetails),
                  ),
                  TextButton(
                    onPressed: onCompare,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(HebrewStrings.compareQuotes),
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
