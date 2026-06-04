import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = MemoryCatalogSearchRepository(
    categories: const [
      CatalogCategory(id: '7', name: 'חיפוי', nameLower: 'חיפוי'),
    ],
    products: const [
      CatalogProduct(
        id: '11',
        name: 'דבק פיקס',
        primaryCategoryId: '7',
        categoryIds: ['7'],
        nameLower: 'דבק פיקס',
        sku: 'FX-1',
      ),
    ],
    variants: [
      const CatalogVariant(
        id: 'v1',
        productId: '11',
        name: 'לבן',
        nameLower: 'לבן',
        displayName: 'דבק פיקס — לבן',
        displayNameLower: 'דבק פיקס — לבן',
        skuLower: 'fx-1',
        categoryIds: ['7'],
        primaryCategoryId: '7',
        searchTokens: ['דבק', 'פיקס', 'fx-1'],
        sortOrder: 1,
      ),
      const CatalogVariant(
        id: 'v2',
        productId: '11',
        name: 'אפור',
        nameLower: 'אפור',
        displayName: 'דבק פיקס — אפור',
        displayNameLower: 'דבק פיקס — אפור',
        categoryIds: ['7'],
        searchTokens: ['דבק', 'אפור'],
        sortOrder: 2,
      ),
      const CatalogVariant(
        id: 'v3',
        productId: '11',
        name: 'שחור',
        nameLower: 'שחור',
        displayNameLower: 'דבק פיקס — שחור',
        categoryIds: ['7'],
        searchTokens: ['שחור'],
        sortOrder: 3,
        status: 'Inactive',
        isActiveInIndex: false,
      ),
    ],
  );

  test('browseVariantsByCategory excludes inactive variants', () async {
    final page = await repo.browseVariantsByCategory(
      const CatalogSearchQuery(categoryId: '7', limit: 10),
    );
    expect(page.hits.length, 2);
    expect(page.hits.map((h) => h.variant.id).toSet(), {'v1', 'v2'});
    expect(page.hits.every((h) => h.variant.isActive), isTrue);
  });

  test('searchVariants matches token', () async {
    final page = await repo.searchVariants(
      const CatalogSearchQuery(text: 'דבק', limit: 10),
    );
    expect(page.hits.length, 2);
    expect(page.hits.first.product?.name, 'דבק פיקס');
  });

  test('searchVariants paginates', () async {
    final page1 = await repo.searchVariants(
      const CatalogSearchQuery(text: 'דבק', limit: 1),
    );
    expect(page1.hasMore, isTrue);
    expect(page1.nextPageToken, isNotNull);

    final page2 = await repo.searchVariants(
      CatalogSearchQuery(
        text: 'דבק',
        limit: 1,
        pageToken: page1.nextPageToken,
      ),
    );
    expect(page2.hits.length, 1);
    expect(page2.hits.first.variant.id, isNot(page1.hits.first.variant.id));
  });

  test('getCategoryTree and getById', () async {
    expect((await repo.getCategoryTree()).length, 1);
    expect((await repo.getVariantById('v1'))?.name, 'לבן');
    expect((await repo.getProductById('11'))?.sku, 'FX-1');
  });
}
