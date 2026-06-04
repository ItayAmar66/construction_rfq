import '../models/quote_request_item.dart';
import '../services/quote_service.dart';

/// Builds supplier quote line input from RFQ line + supplier choices.
class SupplierQuoteLineMapper {
  SupplierQuoteLineMapper._();

  static SupplierQuoteLineInput fromRequestLine({
    required QuoteRequestItem requestItem,
    required double unitPrice,
    required int requestedQuantity,
    required bool includeInQuote,
    bool isExactMatch = true,
    String quotedName = '',
    String quotedSku = '',
    String supplierNotes = '',
  }) {
    final isCatalog = requestItem.isCatalogMatched;
    final exact = isCatalog && isExactMatch;
    final alternative = isCatalog && !isExactMatch;
    final resolvedQuotedName = isCatalog
        ? (exact
            ? requestItem.productName
            : quotedName.trim().isEmpty
                ? requestItem.productName
                : quotedName.trim())
        : requestItem.productName;
    final resolvedQuotedSku = isCatalog
        ? (exact
            ? (requestItem.sku ?? '')
            : quotedSku.trim())
        : '';

    return SupplierQuoteLineInput(
      requestItemId: requestItem.id,
      productId: requestItem.productId,
      variantId: exact ? requestItem.variantId : null,
      productName: resolvedQuotedName,
      quotedName: isCatalog ? resolvedQuotedName : null,
      quotedSku: isCatalog && resolvedQuotedSku.isNotEmpty
          ? resolvedQuotedSku
          : null,
      requestedQuantity: requestedQuantity,
      unitPrice: unitPrice,
      totalItemPrice: unitPrice * requestedQuantity,
      notes: supplierNotes.isEmpty ? null : supplierNotes,
      supplierNotes: supplierNotes.isEmpty ? null : supplierNotes,
      isExactMatch: exact,
      isAlternative: alternative,
      includeInQuote: includeInQuote,
    );
  }
}
