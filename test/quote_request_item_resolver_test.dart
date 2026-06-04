import 'package:construction_rfq/models/cart_item.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/product.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/utils/quote_request_item_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveQuoteRequestItems', () {
    test('prefers explicit request items over cart', () {
      const items = [
        QuoteRequestItem(
          id: 'line-1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Catalog line',
          category: 'cat',
          unitType: 'יח',
          quantity: 1,
          isCatalogMatched: true,
        ),
      ];

      final resolved = resolveQuoteRequestItems(
        requestItems: items,
        cartItems: [
          CartItem(
            product: const Product(
              id: 'legacy',
              name: 'Legacy',
              category: 'c',
              unitType: 'u',
              brand: '',
              sku: '',
              description: '',
              variant: '',
            ),
            quantity: 1,
          ),
        ],
      );

      expect(resolved, hasLength(1));
      expect(resolved.first.productName, 'Catalog line');
    });
  });

  group('cloneQuoteRequestItemForPersist', () {
    test('copies snapshot fields for Firestore persist', () {
      final source = QuoteRequestItem.fromCatalogDraft(
        const CatalogRfqLineDraft(
          variantId: 'v1',
          productId: '11',
          categoryId: '7',
          categoryPath: 'דבקים',
          displayName: 'דבק — לבן',
          productName: 'דבק',
          variantName: 'לבן',
          sku: 'FX-1',
          imagePath: '/img/x.jpg',
        ),
        lineId: 'line-1',
      );

      final cloned = cloneQuoteRequestItemForPersist(
        source,
        requestId: 'req-1',
        lineId: 'line-1',
      );

      expect(cloned.quoteRequestId, 'req-1');
      expect(cloned.variantName, 'לבן');
      expect(cloned.catalogProductName, 'דבק');
      expect(cloned.imagePath, '/img/x.jpg');
    });
  });
}
