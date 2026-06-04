import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/repositories/catalog_search/firestore_catalog_search_query_builder.dart';
import 'package:construction_rfq/repositories/catalog_search/firestore_rest_structured_query_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('REST encoder builds runQuery body for category browse', () {
    final query = const CatalogSearchQuery(categoryId: '7', limit: 10);
    final plan = FirestoreCatalogSearchQueryBuilder.plan(query);
    final body = FirestoreRestStructuredQueryEncoder.encode(
      collectionId: 'catalogVariants',
      plan: plan,
      limit: 11,
    );

    final structured = body['structuredQuery'] as Map<String, dynamic>;
    expect(structured['from'], [
      {'collectionId': 'catalogVariants'},
    ]);
    expect(structured['limit'], 11);

    final where = structured['where'] as Map<String, dynamic>;
    final composite = where['compositeFilter'] as Map<String, dynamic>;
    expect(composite['op'], 'AND');
    final filters = composite['filters'] as List;
    expect(filters.length, greaterThanOrEqualTo(2));
  });

  test('encodeFromSearchQuery matches plan for token search', () {
    final body = FirestoreRestStructuredQueryEncoder.encodeFromSearchQuery(
      collectionId: 'catalogVariants',
      query: const CatalogSearchQuery(text: 'דבק', limit: 5),
      limit: 6,
    );
    final structured = body['structuredQuery'] as Map<String, dynamic>;
    expect(structured['limit'], 6);
    expect(structured['orderBy'], isNotEmpty);
  });
}
