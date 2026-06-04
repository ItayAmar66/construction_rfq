import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_hit.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromSearchHit builds draft RFQ line snapshot', () {
    const hit = CatalogSearchHit(
      variant: CatalogVariant(
        id: 'v1',
        productId: '11',
        name: 'לבן',
        displayName: 'דבק פיקס — לבן',
        categoryIds: ['7'],
        primaryCategoryId: '7',
        categoryPathText: 'דבקים › חיפוי',
        sizeLabel: '25 ק״ג',
      ),
      product: CatalogProduct(
        id: '11',
        name: 'דבק פיקס',
        sku: 'FX-1',
        unitType: 'שק',
        packagingLabel: '25 ק״ג',
        categoryIds: ['7'],
        primaryCategoryId: '7',
      ),
      categoryBreadcrumb: 'דבקים › חיפוי',
    );

    final draft = CatalogRfqLineDraft.fromSearchHit(hit);
    expect(draft.variantId, 'v1');
    expect(draft.productId, '11');
    expect(draft.categoryId, '7');
    expect(draft.categoryPath, 'דבקים › חיפוי');
    expect(draft.displayName, 'דבק פיקס — לבן');
    expect(draft.sku, 'FX-1');
    expect(draft.unitType, 'שק');
    expect(draft.packagingLabel, '25 ק״ג');
    expect(draft.quantity, 1);
    expect(draft.notes, '');
    expect(draft.isCatalogMatched, isTrue);
  });
}
