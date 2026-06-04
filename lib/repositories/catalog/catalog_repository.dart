import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_list_query.dart';
import '../../models/catalog/catalog_meta.dart';
import '../../models/catalog/catalog_page.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_variant.dart';

/// Read-only catalog data access (Firestore or in-memory for tests/demo slice).
abstract class CatalogRepository {
  Future<CatalogMeta> getMeta();

  Stream<CatalogMeta> watchMeta();

  /// Full category tree (418 nodes — single fetch, cached by caller).
  Future<List<CatalogCategory>> loadCategories();

  Future<CatalogPage<CatalogProduct>> listProducts(CatalogListQuery query);

  Future<CatalogProduct?> getProduct(String productId);

  Future<List<CatalogVariant>> getVariantsForProduct(
    String productId, {
    bool activeOnly = true,
  });

  Future<CatalogVariant?> getVariant(String variantId);
}
