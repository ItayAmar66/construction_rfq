import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quote_request_item.dart';
import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../providers/providers.dart';
import '../../utils/customer_quote_match_helpers.dart';
import 'customer_quote_line_match_card.dart';

/// Supplier-facing quote line list with catalog match context.
class SupplierQuoteItemsSection extends ConsumerWidget {
  const SupplierQuoteItemsSection({
    super.key,
    required this.quote,
    this.compact = false,
  });

  final SupplierQuote quote;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestItems =
        ref.watch(quoteRequestProvider(quote.quoteRequestId)).valueOrNull?.items ??
            const <QuoteRequestItem>[];
    final requestItemsById = indexRequestItemsById(requestItems);

    Widget buildList(List<SupplierQuoteItem> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        children: items
            .map(
              (item) => CustomerQuoteLineMatchCard(
                quoteItem: item,
                requestLine: requestLineForQuoteItem(item, requestItemsById),
                compact: compact,
              ),
            )
            .toList(),
      );
    }

    if (quote.items.isNotEmpty) {
      return buildList(quote.items);
    }

    return FutureBuilder<List<SupplierQuoteItem>>(
      future: ref.read(quoteServiceProvider).getSupplierQuoteItems(quote.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(compact ? 12 : 24),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return buildList(snapshot.data ?? const []);
      },
    );
  }
}
