import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/repositories/catalog_search/firestore_catalog_search_query_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category browse plan uses categoryIds arrayContains', () {
    final plan = FirestoreCatalogSearchQueryBuilder.plan(
      const CatalogSearchQuery(categoryId: '418', limit: 24),
    );
    expect(plan.strategy, CatalogFirestoreSearchStrategy.categoryBrowse);
    expect(plan.arrayContainsField, 'categoryIds');
    expect(plan.arrayContainsValue, '418');
    expect(plan.equalityFilters['isActive'], true);
  });

  test('text plan prefers search token when words present', () {
    final plan = FirestoreCatalogSearchQueryBuilder.plan(
      const CatalogSearchQuery(text: 'דבק פיקס', limit: 24),
    );
    expect(plan.strategy, CatalogFirestoreSearchStrategy.searchToken);
    expect(plan.arrayContainsField, 'searchTokens');
    expect(plan.arrayContainsValue, isNotEmpty);
  });

  test('sku-like text uses sku prefix plan', () {
    final plan = FirestoreCatalogSearchQueryBuilder.plan(
      const CatalogSearchQuery(text: 'fx-100', limit: 24),
    );
    expect(plan.strategy, CatalogFirestoreSearchStrategy.skuPrefix);
    expect(plan.rangeField, 'skuLower');
  });

  test('page token round-trip', () {
    final encoded = FirestoreCatalogSearchQueryBuilder.encodePageToken(
      'דבק',
      'doc-1',
    );
    final parsed = FirestoreCatalogSearchQueryBuilder.parsePageToken(encoded);
    expect(parsed.docId, 'doc-1');
    expect(parsed.nameLower, 'דבק');
  });
}
