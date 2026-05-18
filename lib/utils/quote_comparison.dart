import '../models/supplier_quote.dart';
import 'supplier_quote_status.dart';

class QuoteComparisonHints {
  const QuoteComparisonHints({
    required this.bestPriceQuoteIds,
    required this.fastestDeliveryQuoteIds,
  });

  final Set<String> bestPriceQuoteIds;
  final Set<String> fastestDeliveryQuoteIds;

  static QuoteComparisonHints fromQuotes(List<SupplierQuote> quotes) {
    final active = quotes
        .where((q) => q.status == SupplierQuoteStatus.sent && !q.isOutdated)
        .toList();
    if (active.isEmpty) {
      return const QuoteComparisonHints(
        bestPriceQuoteIds: {},
        fastestDeliveryQuoteIds: {},
      );
    }

    final minPrice = active
        .map((q) => q.displayTotal)
        .reduce((a, b) => a < b ? a : b);
    final bestIds = active
        .where((q) => (q.displayTotal - minPrice).abs() < 0.01)
        .map((q) => q.id)
        .toSet();

    final withDelivery =
        active.where((t) => t.deliveryTime.trim().isNotEmpty).toList();
    final fastestIds = <String>{};
    if (withDelivery.isNotEmpty) {
      withDelivery.sort(
        (a, b) => a.deliveryTime.trim().length.compareTo(
              b.deliveryTime.trim().length,
            ),
      );
      final shortest = withDelivery.first.deliveryTime.trim().length;
      fastestIds.addAll(
        withDelivery
            .where((q) => q.deliveryTime.trim().length == shortest)
            .map((q) => q.id),
      );
    }

    return QuoteComparisonHints(
      bestPriceQuoteIds: bestIds,
      fastestDeliveryQuoteIds: fastestIds,
    );
  }
}
