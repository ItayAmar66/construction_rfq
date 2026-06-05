import 'package:construction_rfq/data/demo_catalog_search_data.dart';
import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_page.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/repositories/catalog_search/catalog_search_repository.dart';
import 'package:construction_rfq/repositories/catalog_search/fallback_catalog_search_repository.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingCatalogSearchRepository implements CatalogSearchRepository {
  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    throw Exception('failed-precondition: missing index');
  }

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(
    CatalogSearchQuery query,
  ) async {
    throw Exception('permission-denied');
  }

  @override
  Future<CatalogProduct?> getProductById(String productId) async {
    throw Exception('unavailable');
  }

  @override
  Future<CatalogVariant?> getVariantById(String variantId) async {
    throw Exception('unavailable');
  }

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) async {
    throw Exception('permission-denied');
  }
}

class _EmptyTreeMemoryRepository extends MemoryCatalogSearchRepository {
  _EmptyTreeMemoryRepository({required super.variants})
      : super(categories: const [], products: const []);
}

void main() {
  test('falls back when primary getCategoryTree throws', () async {
    final repo = FallbackCatalogSearchRepository(
      primary: _ThrowingCatalogSearchRepository(),
      fallback: DemoCatalogSearchData.repository(),
    );

    final categories = await repo.getCategoryTree();
    expect(categories, isNotEmpty);
    expect(repo.usingFallback, isTrue);
  });

  test('empty primary category tree does not activate fallback', () async {
    final repo = FallbackCatalogSearchRepository(
      primary: _EmptyTreeMemoryRepository(
        variants: DemoCatalogSearchData.variants,
      ),
      fallback: DemoCatalogSearchData.repository(),
    );

    final categories = await repo.getCategoryTree();
    expect(categories, isEmpty);
    expect(repo.usingFallback, isFalse);

    final page = await repo.searchVariants(const CatalogSearchQuery(limit: 10));
    expect(page.hits, isNotEmpty);
    expect(repo.usingFallback, isFalse);
  });

  test('searchVariants uses fallback after primary failure', () async {
    final repo = FallbackCatalogSearchRepository(
      primary: _ThrowingCatalogSearchRepository(),
      fallback: DemoCatalogSearchData.repository(),
    );

    final page = await repo.searchVariants(
      const CatalogSearchQuery(text: 'דבק', limit: 10),
    );
    expect(page.hits, isNotEmpty);
    expect(page.hits.map((h) => h.variant.id), contains('v1'));
    expect(repo.usingFallback, isTrue);
  });
}
