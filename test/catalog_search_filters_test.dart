import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/repositories/catalog_search/firestore_catalog_search_query_builder.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreCatalogSearchQueryBuilder', () {
    test('pure alpha name uses text search not sku prefix', () {
      const query = CatalogSearchQuery(text: 'productname');
      final plan = FirestoreCatalogSearchQueryBuilder.plan(query);

      expect(plan.strategy, isNot(CatalogFirestoreSearchStrategy.skuPrefix));
      expect(plan.strategy, CatalogFirestoreSearchStrategy.searchToken);
    });

    test('sku-like query uses skuPrefix strategy', () {
      const query = CatalogSearchQuery(text: 'fx-100');
      final plan = FirestoreCatalogSearchQueryBuilder.plan(query);

      expect(plan.strategy, CatalogFirestoreSearchStrategy.skuPrefix);
      expect(plan.equalityFilters['isActive'], isTrue);
    });

    test('category browse filters active variants', () {
      const query = CatalogSearchQuery(categoryId: '7');
      final plan = FirestoreCatalogSearchQueryBuilder.plan(query);

      expect(plan.strategy, CatalogFirestoreSearchStrategy.categoryBrowse);
      expect(plan.equalityFilters['isActive'], isTrue);
    });
  });

  group('MemoryCatalogSearchRepository ranking', () {
    test('exact sku ranks before name matches', () async {
      final repo = MemoryCatalogSearchRepository(
        variants: const [
          CatalogVariant(
            id: 'v-name',
            productId: 'p1',
            name: 'ABC123 lookalike',
            displayName: 'ABC123 lookalike',
            displayNameLower: 'abc123 lookalike',
            nameLower: 'abc123 lookalike',
            categoryIds: ['7'],
            primaryCategoryId: '7',
            searchTokens: ['abc123'],
            skuLower: 'other-1',
          ),
          CatalogVariant(
            id: 'v-sku',
            productId: 'p2',
            name: 'Exact SKU',
            displayName: 'Exact SKU',
            displayNameLower: 'exact sku',
            nameLower: 'exact sku',
            categoryIds: ['7'],
            primaryCategoryId: '7',
            searchTokens: ['exact'],
            skuLower: 'abc123',
          ),
        ],
      );

      final page = await repo.searchVariants(
        const CatalogSearchQuery(text: 'abc123', limit: 10),
      );

      expect(page.hits.first.variant.id, 'v-sku');
    });
  });
}
