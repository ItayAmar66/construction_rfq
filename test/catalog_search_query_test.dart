import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CatalogSearchQuery clamps limit', () {
    const q = CatalogSearchQuery(limit: 200);
    expect(q.effectiveLimit, 50);
    expect(const CatalogSearchQuery(limit: 0).effectiveLimit, 1);
  });

  test('CatalogSearchQuery detects text and category', () {
    expect(const CatalogSearchQuery().hasText, isFalse);
    expect(const CatalogSearchQuery(text: '  דבק  ').hasText, isTrue);
    expect(const CatalogSearchQuery(categoryId: '7').hasCategory, isTrue);
  });

  test('CatalogSearchResult factory helpers', () {
    expect(CatalogSearchResult.loading().isLoading, isTrue);
    expect(
      CatalogSearchResult.failure('x').errorMessage,
      'x',
    );
  });
}
