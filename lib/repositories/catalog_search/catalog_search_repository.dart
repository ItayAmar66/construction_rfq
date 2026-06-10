import '../../models/catalog/catalog_availability.dart';
import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_search_page.dart';
import '../../models/catalog/catalog_search_query.dart';
import '../../models/catalog/catalog_variant.dart';

/// Variant-centric catalog search and browse (Firestore MVP; swappable later).
abstract class CatalogSearchRepository {
  /// Full category tree for navigation filters.
  Future<List<CatalogCategory>> getCategoryTree();

  /// First page of categories for fast chip row (bounded query).
  Future<List<CatalogCategory>> getTopCategories({int limit = 48});

  Future<CatalogVariant?> getVariantById(String variantId);

  Future<CatalogProduct?> getProductById(String productId);

  /// Text/SKU token search over variants (paginated).
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query);

  /// Browse variants in a category (paginated).
  Future<CatalogSearchPage> browseVariantsByCategory(CatalogSearchQuery query);

  /// Whether `catalogMeta/current` and imported counts indicate a usable catalog.
  Future<CatalogAvailability> getCatalogAvailability();
}
