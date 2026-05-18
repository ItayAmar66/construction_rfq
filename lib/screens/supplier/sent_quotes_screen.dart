import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
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
                subtitle: Column(
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
                  ],
                ),
                children: [
                  if (quote.items.isNotEmpty)
                    ...quote.items.map(
                      (item) => ListTile(
                        dense: true,
                        title: Text(item.productName),
                        trailing: Text(
                          '₪${item.totalItemPrice.toStringAsFixed(2)}',
                        ),
                      ),
                    )
                  else
                    FutureBuilder<List<SupplierQuoteItem>>(
                      future: ref
                          .read(quoteServiceProvider)
                          .getSupplierQuoteItems(quote.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        return Column(
                          children: snapshot.data!.map((item) {
                            return ListTile(
                              dense: true,
                              title: Text(item.productName),
                              trailing: Text(
                                '₪${item.totalItemPrice.toStringAsFixed(2)}',
                              ),
                            );
                          }).toList(),
                        );
                      },
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
