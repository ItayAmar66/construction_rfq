import '../models/quote_request_item.dart';
import '../models/supplier_quote_item.dart';

Map<String, QuoteRequestItem> indexRequestItemsById(
  Iterable<QuoteRequestItem> items,
) {
  return {for (final item in items) item.id: item};
}

QuoteRequestItem? requestLineForQuoteItem(
  SupplierQuoteItem quoteItem,
  Map<String, QuoteRequestItem> requestItemsById,
) {
  final requestItemId = quoteItem.requestItemId;
  if (requestItemId == null || requestItemId.isEmpty) return null;
  return requestItemsById[requestItemId];
}

bool quoteHasAlternativeItems(Iterable<SupplierQuoteItem> items) {
  return items.any((item) => item.isAlternative);
}

int alternativeItemCount(Iterable<SupplierQuoteItem> items) {
  return items.where((item) => item.isAlternative).length;
}

bool shouldShowCatalogMatchUi(
  SupplierQuoteItem quoteItem,
  QuoteRequestItem? requestLine,
) {
  if (requestLine?.isCatalogMatched == true) return true;
  return quoteItem.isExactMatch || quoteItem.isAlternative;
}
