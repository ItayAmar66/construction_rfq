import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_search_page.dart';
import '../../models/catalog/catalog_search_query.dart';
import '../../models/catalog/catalog_variant.dart';
import 'catalog_search_repository.dart';

/// Optional external search backend (Algolia/Typesense/Meilisearch) — not wired.
abstract class ExternalCatalogSearchAdapter implements CatalogSearchRepository {
  const ExternalCatalogSearchAdapter();

  /// Adapter identifier for logging/config.
  String get backendName;

  /// Whether adapter is configured (API keys, index name).
  bool get isConfigured;
}

/// Fake adapter for contract tests — delegates to inner Firestore repo.
class DelegatingCatalogSearchAdapter implements ExternalCatalogSearchAdapter {
  DelegatingCatalogSearchAdapter(this._inner);

  final CatalogSearchRepository _inner;

  @override
  String get backendName => 'delegating';

  @override
  bool get isConfigured => true;

  @override
  Future<List<CatalogCategory>> getCategoryTree() => _inner.getCategoryTree();

  @override
  Future<CatalogVariant?> getVariantById(String id) => _inner.getVariantById(id);

  @override
  Future<CatalogProduct?> getProductById(String id) =>
      _inner.getProductById(id);

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) =>
      _inner.searchVariants(query);

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(CatalogSearchQuery query) =>
      _inner.browseVariantsByCategory(query);
}
