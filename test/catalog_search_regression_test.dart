import 'package:construction_rfq/catalog_import/catalog_text_utils.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/repositories/catalog_search/firestore_catalog_search_query_builder.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Catalog search regression', () {
    test('category + text uses scoped search not category-only', () {
      const query = CatalogSearchQuery(
        text: 'דבק',
        categoryId: '7',
      );
      final plan = FirestoreCatalogSearchQueryBuilder.plan(query);
      expect(plan.scopeCategoryId, '7');
      expect(plan.strategy, isNot(CatalogFirestoreSearchStrategy.categoryBrowse));
    });

    test('pure Hebrew query uses token search not sku prefix', () {
      expect(CatalogTextUtils.looksLikeSkuQuery('דבק פיקס'), isFalse);
      const query = CatalogSearchQuery(text: 'דבק');
      final plan = FirestoreCatalogSearchQueryBuilder.plan(query);
      expect(plan.strategy, CatalogFirestoreSearchStrategy.searchToken);
    });

    test('sku-like query uses sku prefix', () {
      expect(CatalogTextUtils.looksLikeSkuQuery('fx-100'), isTrue);
      const query = CatalogSearchQuery(text: 'fx-100');
      final plan = FirestoreCatalogSearchQueryBuilder.plan(query);
      expect(plan.strategy, CatalogFirestoreSearchStrategy.skuPrefix);
    });

    test('memory repo paginates with category filter', () async {
      final variants = List.generate(
        60,
        (i) => CatalogVariant(
          id: 'v$i',
          productId: 'p$i',
          name: 'item$i',
          displayName: 'item $i',
          displayNameLower: 'item $i',
          nameLower: 'item$i',
          categoryIds: const ['c1'],
          primaryCategoryId: 'c1',
          searchTokens: const ['item'],
          skuLower: 'sku$i',
        ),
      );
      final repo = MemoryCatalogSearchRepository(variants: variants);
      final page1 = await repo.searchVariants(
        const CatalogSearchQuery(categoryId: 'c1', limit: 50),
      );
      expect(page1.hits.length, 50);
      expect(page1.hasMore, isTrue);
      final page2 = await repo.searchVariants(
        CatalogSearchQuery(
          categoryId: 'c1',
          limit: 50,
          pageToken: page1.nextPageToken,
        ),
      );
      expect(page2.hits.length, 10);
    });
  });
}
