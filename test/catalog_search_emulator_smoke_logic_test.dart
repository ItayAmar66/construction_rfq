import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/repositories/catalog_search/emulator_rest_catalog_search_repository.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickBrowseSeedFromVariants uses categoryIds not category productCount',
      () {
    expect(
      EmulatorRestCatalogSearchRepository.categoryIdForBrowse(
        const CatalogVariant(
          id: 'v1',
          productId: 'p1',
          name: 'x',
          primaryCategoryId: '42',
          categoryIds: ['42', '7'],
        ),
      ),
      '42',
    );
    expect(
      EmulatorRestCatalogSearchRepository.categoryIdForBrowse(
        const CatalogVariant(
          id: 'v2',
          productId: 'p1',
          name: 'x',
          categoryIds: ['99'],
        ),
      ),
      '99',
    );
  });

  test('smoke does not require category hasProducts when seed has categoryIds',
      () async {
    final repo = MemoryCatalogSearchRepository(
      categories: const [
        CatalogCategory(
          id: '7',
          name: 'חיפוי',
          hasProducts: false,
          productCount: 0,
        ),
      ],
      products: const [
        CatalogProduct(
          id: '11',
          name: 'דבק',
          primaryCategoryId: '7',
          categoryIds: ['7'],
          searchTokens: ['דבק'],
          nameLower: 'דבק',
        ),
      ],
      variants: const [
        CatalogVariant(
          id: 'v1',
          productId: '11',
          name: 'לבן',
          categoryIds: ['7'],
          primaryCategoryId: '7',
          searchTokens: ['דבק', 'לבן'],
          displayNameLower: 'דבק לבן',
          nameLower: 'לבן',
        ),
      ],
    );

    // Memory repo: smoke only resolves seed via REST — test browse path directly
    final browse = await repo.browseVariantsByCategory(
      const CatalogSearchQuery(categoryId: '7', limit: 5),
    );
    expect(browse.hits, isNotEmpty);
  });
}
