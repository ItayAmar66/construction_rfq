import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/providers.dart';
import '../../services/quote_service.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/quote_status_badge.dart';

class QuoteCompareScreen extends ConsumerWidget {
  const QuoteCompareScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(requestQuotesProvider(requestId));

    return Scaffold(
      appBar: const SecondaryAppBar(title: HebrewStrings.compareQuotes),
      body: quotesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => const Center(child: Text(HebrewStrings.errorGeneric)),
        data: (quotes) {
          final list = quotes;
          if (list.isEmpty) {
            return const Center(
              child: Text('עדיין לא התקבלו הצעות לבקשה זו'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) => _QuoteCard(
              quote: list[i],
              ref: ref,
              requestId: requestId,
            ),
          );
        },
      ),
    );
  }
}

class _QuoteItemsList extends StatelessWidget {
  const _QuoteItemsList({required this.quote, required this.ref});

  final SupplierQuote quote;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (quote.items.isNotEmpty) {
      return Column(
        children: quote.items.map(_itemTile).toList(),
      );
    }

    return FutureBuilder<List<SupplierQuoteItem>>(
      future: ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }
        return Column(children: snapshot.data!.map(_itemTile).toList());
      },
    );
  }

  Widget _itemTile(SupplierQuoteItem item) {
    return ListTile(
      dense: true,
      title: Text(item.productName),
      subtitle: Text('כמות: ${item.requestedQuantity}'),
      trailing: Text(
        '₪${item.unitPrice} × ${item.requestedQuantity} = '
        '₪${item.totalItemPrice.toStringAsFixed(2)}',
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.ref,
    required this.requestId,
  });

  final SupplierQuote quote;
  final WidgetRef ref;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(quote.supplierName)),
            QuoteStatusBadge(status: quote.status),
          ],
        ),
        subtitle: Text(
          '${HebrewStrings.deliveryTime}: ${quote.deliveryTime} · '
          '₪${quote.totalPrice.toStringAsFixed(2)}',
        ),
        children: [
          _QuoteItemsList(quote: quote, ref: ref),
          if (quote.notes != null && quote.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('${HebrewStrings.notes}: ${quote.notes}'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.push(
                  '/quote-detail/${quote.id}?requestId=$requestId',
                ),
                child: const Text(HebrewStrings.viewQuoteDetails),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
