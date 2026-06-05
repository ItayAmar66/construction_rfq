import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/repositories/catalog_search/external_catalog_search_adapter.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DelegatingCatalogSearchAdapter forwards search to inner repo', () async {
    final inner = MemoryCatalogSearchRepository(
      categories: const [],
      variants: const [],
    );
    final adapter = DelegatingCatalogSearchAdapter(inner);

    expect(adapter.backendName, 'delegating');
    expect(adapter.isConfigured, isTrue);

    final page = await adapter.searchVariants(const CatalogSearchQuery(text: 'x'));
    expect(page.hits, isEmpty);
  });
}
