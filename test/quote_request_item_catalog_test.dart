import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/catalog/catalog_search_hit.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/models/product.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuoteRequestItem catalog mapping', () {
    test('fromCatalogDraft preserves catalog snapshot fields', () {
      const draft = CatalogRfqLineDraft(
        variantId: 'v1',
        productId: '11',
        categoryId: '7',
        categoryPath: 'דבקים › חיפוי',
        displayName: 'דבק פיקס — לבן',
        sku: 'FX-1',
        unitType: 'שק',
        packagingLabel: '25 ק״ג',
        quantity: 2,
        notes: 'לבן',
        isCatalogMatched: true,
      );

      final item = QuoteRequestItem.fromCatalogDraft(
        draft,
        lineId: 'line-1',
      );

      expect(item.variantId, 'v1');
      expect(item.productId, '11');
      expect(item.categoryId, '7');
      expect(item.categoryPath, 'דבקים › חיפוי');
      expect(item.productName, 'דבק פיקס — לבן');
      expect(item.sku, 'FX-1');
      expect(item.unitType, 'שק');
      expect(item.packagingLabel, '25 ק״ג');
      expect(item.quantity, 2);
      expect(item.notes, 'לבן');
      expect(item.isCatalogMatched, isTrue);
    });

    test('fromSearchHit draft round-trips through request item', () {
      const hit = CatalogSearchHit(
        variant: CatalogVariant(
          id: 'v1',
          productId: '11',
          name: 'לבן',
          displayName: 'דבק פיקס — לבן',
          categoryIds: ['7'],
          primaryCategoryId: '7',
          categoryPathText: 'דבקים › חיפוי',
        ),
        product: CatalogProduct(
          id: '11',
          name: 'דבק פיקס',
          sku: 'FX-1',
          unitType: 'שק',
          categoryIds: ['7'],
          primaryCategoryId: '7',
        ),
        categoryBreadcrumb: 'דבקים › חיפוי',
      );

      final draft = CatalogRfqLineDraft.fromSearchHit(hit);
      final item = QuoteRequestItem.fromCatalogDraft(
        draft,
        lineId: 'line-2',
      );

      expect(item.isCatalogMatched, isTrue);
      expect(item.variantId, 'v1');
      expect(item.productName, 'דבק פיקס — לבן');
      expect(item.catalogProductName, 'דבק פיקס');
      expect(item.variantName, 'לבן');
    });

    test('fromCatalogDraft preserves hardened snapshot fields', () {
      const draft = CatalogRfqLineDraft(
        variantId: 'v1',
        productId: '11',
        categoryId: '7',
        categoryPath: 'דבקים › חיפוי',
        displayName: 'דבק פיקס — לבן',
        productName: 'דבק פיקס',
        variantName: 'לבן',
        sku: 'FX-1',
        unitType: 'שק',
        packagingLabel: '25 ק״ג',
        imagePath: 'catalog/images/x.jpg',
        attributesSnapshot: {'color': 'white'},
        sourceCatalogVersion: '2026-06',
        quantity: 2,
      );

      final item = QuoteRequestItem.fromCatalogDraft(
        draft,
        lineId: 'line-1',
      );

      expect(item.catalogProductName, 'דבק פיקס');
      expect(item.variantName, 'לבן');
      expect(item.imagePath, 'catalog/images/x.jpg');
      expect(item.attributesSnapshot['color'], 'white');
      expect(item.sourceCatalogVersion, '2026-06');
    });

    test('fromEmbedded tolerates old items without new fields', () {
      final item = QuoteRequestItem.fromEmbedded(
        requestId: 'req-old',
        map: const {
          'productId': 'p1',
          'productName': 'Old item',
          'category': 'cat',
          'unitType': 'u',
          'quantity': 1,
          'isCatalogMatched': false,
        },
        index: 0,
      );

      expect(item.variantName, isNull);
      expect(item.imagePath, isNull);
      expect(item.attributesSnapshot, isEmpty);
    });

    test('fromLegacyProduct keeps manual item unmatched', () {
      const product = Product(
        id: 'p1',
        name: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        brand: '',
        sku: '',
        description: '',
        variant: '',
      );

      final item = QuoteRequestItem.fromLegacyProduct(
        product: product,
        quantity: 3,
        lineId: 'line-3',
      );

      expect(item.isCatalogMatched, isFalse);
      expect(item.productId, 'p1');
      expect(item.productName, 'בלוק 20');
      expect(item.variantId, isNull);
    });

    test('toEmbeddedMap writes catalog fields when present', () {
      final item = QuoteRequestItem.fromCatalogDraft(
        const CatalogRfqLineDraft(
          variantId: 'v1',
          productId: '11',
          categoryId: '7',
          categoryPath: 'דבקים › חיפוי',
          displayName: 'דבק פיקס — לבן',
          productName: 'דבק פיקס',
          sku: 'FX-1',
          unitType: 'שק',
          packagingLabel: '25 ק״ג',
        ),
        lineId: 'line-4',
      );

      final map = item.toEmbeddedMap();
      expect(map['variantId'], 'v1');
      expect(map['categoryPath'], 'דבקים › חיפוי');
      expect(map['catalogProductName'], 'דבק פיקס');
      expect(map['isCatalogMatched'], isTrue);
    });
  });
}
