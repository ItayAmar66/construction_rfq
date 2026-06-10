import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/providers/catalog_selector_provider.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/utils/catalog_search_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<CatalogCategory> _manyCategories(int count) {
  return List.generate(
    count,
    (i) => CatalogCategory(
      id: 'c$i',
      name: 'קטגוריה $i',
      nameLower: 'קטגוריה $i',
      sortOrder: i,
    ),
  );
}

void main() {
  setUp(CatalogSelectorNotifier.clearSessionRecentsForTesting);

  test('default page size is bounded', () {
    expect(CatalogSelectorNotifier.pageSize, CatalogSearchConstants.defaultPageSize);
    expect(CatalogSearchQuery().effectiveLimit, lessThanOrEqualTo(100));
  });

  test('getTopCategories returns bounded slice not full tree', () async {
    final repo = MemoryCatalogSearchRepository(
      categories: _manyCategories(200),
      variants: const [],
    );

    final top = await repo.getTopCategories(limit: 48);
    expect(top, hasLength(48));

    final full = await repo.getCategoryTree();
    expect(full, hasLength(200));
  });

  test('catalog selector init uses top categories not full tree', () async {
    final repo = MemoryCatalogSearchRepository(
      categories: _manyCategories(100),
      products: const [
        CatalogProduct(
          id: 'p1',
          name: 'מוצר',
          primaryCategoryId: 'c0',
          categoryIds: ['c0'],
          nameLower: 'מוצר',
        ),
      ],
      variants: const [
        CatalogVariant(
          id: 'v1',
          productId: 'p1',
          name: 'v',
          displayName: 'מוצר',
          displayNameLower: 'מוצר',
          categoryIds: ['c0'],
          searchTokens: ['מוצר'],
          nameLower: 'v',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        catalogSearchRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(catalogSelectorProvider.notifier).initialize();

    final state = container.read(catalogSelectorProvider);
    expect(state.categories.length, lessThanOrEqualTo(48));
    expect(state.allCategoriesLoaded, isFalse);
  });
}
