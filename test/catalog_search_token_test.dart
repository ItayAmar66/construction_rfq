import 'package:construction_rfq/catalog_import/catalog_variant_search_fields.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildVariantSearchTokens includes sku and product name', () {
    final tokens = CatalogVariantSearchFields.buildVariantSearchTokens(
      variantName: 'לבן',
      displayName: 'דבק פיקס — לבן',
      sku: 'FX-100',
      productName: 'דבק פיקס',
      aliases: ['fix glue'],
    );
    expect(tokens, contains('fx 100'));
    expect(tokens.any((t) => t.contains('דבק') || t.contains('פיקס')), isTrue);
  });

  test('enrich copies category ids and path from product', () {
    const product = CatalogProduct(
      id: '11',
      name: 'דבק פיקס',
      sku: 'FX-1',
      categoryIds: ['7', '2'],
      primaryCategoryId: '7',
      categoryPathNames: ['דבקים', 'חיפוי'],
      searchTokens: ['דבק'],
      nameLower: 'דבק פיקס',
    );
    const variant = CatalogVariant(
      id: '99',
      productId: '11',
      name: 'לבן',
      nameLower: 'לבן',
    );

    final enriched = CatalogVariantSearchFields.enrich(variant, product);
    expect(enriched.categoryIds, ['7', '2']);
    expect(enriched.primaryCategoryId, '7');
    expect(enriched.categoryPathText, 'דבקים › חיפוי');
    expect(enriched.skuLower, contains('fx'));
    expect(enriched.displayName, contains('דבק פיקס'));
    expect(enriched.searchTokens, isNotEmpty);
    expect(enriched.isActiveInIndex, isTrue);
  });
}
