import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../models/quote_request_item.dart';

/// Resolves RFQ request lines from explicit items or legacy cart rows.
List<QuoteRequestItem> resolveQuoteRequestItems({
  List<QuoteRequestItem>? requestItems,
  List<CartItem>? cartItems,
  Uuid? uuid,
}) {
  if (requestItems != null && requestItems.isNotEmpty) {
    return requestItems;
  }
  final idGen = uuid ?? const Uuid();
  final items = cartItems ?? const <CartItem>[];
  return items
      .map(
        (item) => QuoteRequestItem.fromLegacyProduct(
          product: item.product,
          quantity: item.quantity,
          lineId: idGen.v4(),
          notes: item.notes,
        ),
      )
      .toList();
}

QuoteRequestItem cloneQuoteRequestItemForPersist(
  QuoteRequestItem item, {
  required String requestId,
  required String lineId,
}) {
  return QuoteRequestItem(
    id: lineId,
    quoteRequestId: requestId,
    productId: item.productId,
    productName: item.productName,
    category: item.category,
    unitType: item.unitType,
    quantity: item.quantity,
    notes: item.notes,
    variantId: item.variantId,
    categoryId: item.categoryId,
    categoryPath: item.categoryPath,
    sku: item.sku,
    packagingLabel: item.packagingLabel,
    variantName: item.variantName,
    catalogProductName: item.catalogProductName,
    imagePath: item.imagePath,
    attributesSnapshot: item.attributesSnapshot,
    sourceCatalogVersion: item.sourceCatalogVersion,
    isCatalogMatched: item.isCatalogMatched,
  );
}
