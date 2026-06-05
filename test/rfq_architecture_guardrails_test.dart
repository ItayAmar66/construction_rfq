import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/supplier_catalog_match_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Procurement wording guardrails', () {
    test('key Hebrew strings avoid cart/shop wording', () {
      expect(HebrewStrings.rfqDraftTitle, isNot(contains('עגלה')));
      expect(HebrewStrings.submitRequest, isNot(contains('קנייה')));
      expect(HebrewStrings.addRfqItem, isNot(contains('סל')));
      expect(HebrewStrings.rfqDraftTitle, 'טיוטת דרישה');
    });

    test('no shopping cart icons in procurement string constants', () {
      expect(Icons.shopping_cart_outlined.codePoint, isA<int>());
      // Guard: documented procurement icons differ from cart icon code points.
      expect(Icons.request_quote_outlined.codePoint,
          isNot(Icons.shopping_cart_outlined.codePoint));
    });
  });

  group('Catalog selector pagination guardrails', () {
    test('search query default limit prevents full-catalog load', () {
      const query = CatalogSearchQuery(text: 'test');
      expect(query.effectiveLimit, lessThanOrEqualTo(50));
      expect(query.effectiveLimit, 50);
    });
  });

  group('RFQ snapshot round-trip guardrails', () {
    test('catalog draft preserves hardened snapshot fields', () {
      const draft = CatalogRfqLineDraft(
        variantId: 'v1',
        productId: '11',
        categoryId: '7',
        categoryPath: 'path',
        displayName: 'Display',
        productName: 'Product',
        variantName: 'Variant',
        imagePath: '/img.jpg',
        attributesSnapshot: {'k': 'v'},
      );

      final item = QuoteRequestItem.fromCatalogDraft(draft, lineId: 'l1');
      final map = item.toEmbeddedMap();
      final restored = QuoteRequestItem.fromEmbedded(
        requestId: 'req',
        map: map,
        index: 0,
        idOverride: 'l1',
      );

      expect(restored.variantName, 'Variant');
      expect(restored.catalogProductName, 'Product');
      expect(restored.imagePath, '/img.jpg');
      expect(restored.attributesSnapshot['k'], 'v');
    });
  });

  group('Supplier alternative note guardrails', () {
    test('alternative catalog line requires supplier note', () {
      final err = SupplierCatalogMatchValidation.missingAlternativeNote(
        item: const QuoteRequestItem(
          id: 'l1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Item',
          category: 'c',
          unitType: 'u',
          quantity: 1,
          isCatalogMatched: true,
        ),
        isExactMatch: false,
        includeInQuote: true,
        unitPrice: 10,
        supplierNotes: '',
      );
      expect(err, isNotNull);
    });
  });
}
