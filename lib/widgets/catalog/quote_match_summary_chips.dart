import 'package:flutter/material.dart';

import '../../models/quote_request_item.dart';
import '../../models/supplier_quote_item.dart';
import '../../utils/customer_quote_match_helpers.dart';
import 'supplier_quote_match_badge.dart';

/// Compact exact/alternative/manual counts for quote list cards.
class QuoteMatchSummaryChips extends StatelessWidget {
  const QuoteMatchSummaryChips({
    super.key,
    required this.items,
    required this.requestItems,
  });

  final List<SupplierQuoteItem> items;
  final List<QuoteRequestItem> requestItems;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final requestItemsById = indexRequestItemsById(requestItems);
    var exact = 0;
    var alternative = 0;
    var manual = 0;

    for (final item in items) {
      final requestLine = requestLineForQuoteItem(item, requestItemsById);
      if (!shouldShowCatalogMatchUi(item, requestLine)) {
        manual++;
      } else if (item.isAlternative) {
        alternative++;
      } else if (item.isExactMatch) {
        exact++;
      }
    }

    if (exact == 0 && alternative == 0 && manual == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (exact > 0)
            const SupplierQuoteMatchBadge(isExactMatch: true, isAlternative: false),
          if (alternative > 0)
            const SupplierQuoteMatchBadge(isExactMatch: false, isAlternative: true),
          if (manual > 0)
            Chip(
              label: Text(
                manual == 1 ? 'פריט ידני' : '$manual פריטים ידניים',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}
