import '../models/quote_request_item.dart';
import '../models/supplier_quote_item.dart';
import 'customer_quote_match_helpers.dart';

/// Metrics for customer quote comparison decision panel.
class QuoteDecisionMetrics {
  const QuoteDecisionMetrics({
    required this.totalPrice,
    required this.exactCount,
    required this.alternativeCount,
    required this.manualCount,
    required this.emptyQuotedLines,
    this.deliveryTime = '',
    this.validUntil,
    this.paymentTerms = '',
  });

  final double totalPrice;
  final int exactCount;
  final int alternativeCount;
  final int manualCount;
  final int emptyQuotedLines;
  final String deliveryTime;
  final DateTime? validUntil;
  final String paymentTerms;
}

QuoteDecisionMetrics computeQuoteDecisionMetrics({
  required Iterable<SupplierQuoteItem> quoteItems,
  required Iterable<QuoteRequestItem> requestItems,
  required double totalPrice,
  String deliveryTime = '',
  DateTime? validUntil,
  String paymentTerms = '',
}) {
  final requestById = indexRequestItemsById(requestItems);
  var exact = 0;
  var alternative = 0;
  var manual = 0;
  var empty = 0;

  for (final item in quoteItems) {
    final requestLine = requestLineForQuoteItem(item, requestById);
    if (requestLine?.isCatalogMatched == true) {
      if (item.isExactMatch) {
        exact++;
      } else if (item.isAlternative) {
        alternative++;
      }
    } else if (!item.isExactMatch && !item.isAlternative) {
      manual++;
    }
    if (item.unitPrice <= 0 || item.displayName.trim().isEmpty) {
      empty++;
    }
  }

  return QuoteDecisionMetrics(
    totalPrice: totalPrice,
    exactCount: exact,
    alternativeCount: alternative,
    manualCount: manual,
    emptyQuotedLines: empty,
    deliveryTime: deliveryTime,
    validUntil: validUntil,
    paymentTerms: paymentTerms,
  );
}
