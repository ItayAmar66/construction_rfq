import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../providers/providers.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/catalog/quote_match_summary_chips.dart';
import '../../widgets/catalog/supplier_quote_items_section.dart';
import '../../widgets/quote_status_badge.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/date_grouped_list.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

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
        error: (_, __) =>
            const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (quotes) {
          if (quotes.isEmpty) {
            return const EmptyState(
              message: 'עדיין לא שלחת הצעות',
              icon: Icons.send_outlined,
            );
          }
          return DateGroupedListView<SupplierQuote>(
            items: quotes,
            dateFor: (q) => q.createdAt,
            itemBuilder: (context, quote) => Card(
              child: ExpansionTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text('₪${quote.totalPrice.toStringAsFixed(2)}'),
                    ),
                    QuoteStatusBadge(status: quote.status),
                  ],
                ),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final requestItems = ref
                            .watch(quoteRequestProvider(quote.quoteRequestId))
                            .valueOrNull
                            ?.items ??
                        const [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (quote.isOutdated)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'הלקוח עדכן את הבקשה לאחר שליחת ההצעה',
                              style: TextStyle(
                                color: AppTheme.amber,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Text(
                          '${HebrewStrings.deliveryTime}: ${quote.deliveryTime}\n'
                          '${dateFormat.format(quote.createdAt)}',
                        ),
                        QuoteMatchSummaryChips(
                          items: quote.items,
                          requestItems: requestItems,
                        ),
                      ],
                    );
                  },
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: SupplierQuoteItemsSection(
                      quote: quote,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
