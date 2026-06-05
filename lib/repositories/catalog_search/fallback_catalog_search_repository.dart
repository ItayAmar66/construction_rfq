import 'package:flutter/foundation.dart';

import '../../config/app_mode.dart';
import '../../data/demo_catalog_search_data.dart';
import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_search_page.dart';
import '../../models/catalog/catalog_search_query.dart';
import '../../models/catalog/catalog_variant.dart';
import 'catalog_search_repository.dart';
import 'firestore_catalog_search_repository.dart';

/// Firestore catalog first; demo slice only on explicit demo mode or query failure.
class FallbackCatalogSearchRepository implements CatalogSearchRepository {
  FallbackCatalogSearchRepository({
    CatalogSearchRepository? primary,
    CatalogSearchRepository? fallback,
  })  : _primary = primary ?? FirestoreCatalogSearchRepository(),
        _fallback = fallback ?? DemoCatalogSearchData.repository();

  final CatalogSearchRepository _primary;
  final CatalogSearchRepository _fallback;

  bool _emergencyFallback = false;

  /// True when reads are served from the emergency demo slice.
  bool get usingFallback => _emergencyFallback;

  bool get _useFallback => AppMode.isDemoMode || _emergencyFallback;

  Future<T> _read<T>(Future<T> Function(CatalogSearchRepository repo) load) async {
    if (_useFallback) {
      return load(_fallback);
    }
    try {
      return await load(_primary);
    } catch (e, st) {
      _emergencyFallback = true;
      if (kDebugMode) {
        debugPrint(
          '[CatalogSearch] Firestore catalog failed, using demo slice: $e\n$st',
        );
      }
      return load(_fallback);
    }
  }

  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    if (AppMode.isDemoMode) {
      return _fallback.getCategoryTree();
    }
    try {
      return await _primary.getCategoryTree();
    } catch (e, st) {
      _emergencyFallback = true;
      if (kDebugMode) {
        debugPrint(
          '[CatalogSearch] getCategoryTree failed, using demo slice: $e\n$st',
        );
      }
      return _fallback.getCategoryTree();
    }
  }

  @override
  Future<CatalogVariant?> getVariantById(String variantId) =>
      _read((repo) => repo.getVariantById(variantId));

  @override
  Future<CatalogProduct?> getProductById(String productId) =>
      _read((repo) => repo.getProductById(productId));

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) =>
      _read((repo) => repo.searchVariants(query));

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(
    CatalogSearchQuery query,
  ) =>
      _read((repo) => repo.browseVariantsByCategory(query));
}
