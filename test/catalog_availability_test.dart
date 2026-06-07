import 'package:construction_rfq/models/catalog/catalog_availability.dart';
import 'package:construction_rfq/models/catalog/catalog_meta.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_selector_browse_test.dart';

void main() {
  test('CatalogAvailability.fromMeta requires meta doc and counts', () {
    const ready = CatalogMeta(
      version: '2026.1',
      variantCount: 100,
      categoryCount: 10,
      productCount: 50,
    );
    expect(
      CatalogAvailability.fromMeta(ready, hasDoc: true).isReady,
      isTrue,
    );

    const empty = CatalogMeta(version: '2026.1');
    expect(
      CatalogAvailability.fromMeta(empty, hasDoc: true).isReady,
      isFalse,
    );
    expect(
      CatalogAvailability.unavailable().isReady,
      isFalse,
    );
  });

  test('memory repository reports ready only with categories and variants', () async {
    final empty = MemoryCatalogSearchRepository();
    expect((await empty.getCatalogAvailability()).isReady, isFalse);

    final ready = paginatedRepo(variantCount: 3);
    final availability = await ready.getCatalogAvailability();
    expect(availability.isReady, isTrue);
    expect(availability.variantCount, 3);
  });

  test('production provider path uses memory repo override without demo slice', () async {
    final repo = paginatedRepo(variantCount: 55);
    final availability = await repo.getCatalogAvailability();
    expect(availability.isReady, isTrue);

    final first = await repo.searchVariants(const CatalogSearchQuery(limit: 50));
    expect(first.hits, hasLength(50));
    expect(first.hasMore, isTrue);
  });
}
