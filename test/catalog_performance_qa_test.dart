import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_selector_provider.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

List<CatalogVariant> _manyVariants(int count) {
  return List.generate(
    count,
    (i) => CatalogVariant(
      id: 'v$i',
      productId: 'p$i',
      name: 'Variant $i',
      displayName: 'Variant $i',
      displayNameLower: 'variant $i',
      nameLower: 'variant $i',
      categoryIds: const ['7'],
      primaryCategoryId: '7',
      searchTokens: const ['variant'],
      skuLower: 'sku-$i',
    ),
  );
}

void main() {
  group('Catalog selector pagination', () {
    test('search returns one page at a time', () async {
      final repo = MemoryCatalogSearchRepository(
        categories: const [
          CatalogCategory(id: '7', name: 'Cat', nameLower: 'cat'),
        ],
        variants: _manyVariants(30),
      );

      final first = await repo.browseVariantsByCategory(
        const CatalogSearchQuery(categoryId: '7', limit: 24),
      );
      expect(first.hits, hasLength(24));
      expect(first.hasMore, isTrue);
      expect(first.nextPageToken, isNotNull);

      final second = await repo.browseVariantsByCategory(
        CatalogSearchQuery(
          categoryId: '7',
          limit: 24,
          pageToken: first.nextPageToken,
        ),
      );
      expect(second.hits, hasLength(6));
      expect(second.hasMore, isFalse);
    });
  });

  group('Selector query limits', () {
    test('default fetch limit is 50 not full catalog', () {
      const query = CatalogSearchQuery(categoryId: '7');
      expect(query.effectiveLimit, 50);
      expect(query.includeInactive, isFalse);
    });

    test('selector state holds one page of hits', () {
      const state = CatalogSelectorState(
        hits: [],
        hasMore: true,
        nextPageToken: 'variant|v24',
      );
      expect(state.hits.length, lessThan(50));
      expect(state.hasMore, isTrue);
    });
  });
}
