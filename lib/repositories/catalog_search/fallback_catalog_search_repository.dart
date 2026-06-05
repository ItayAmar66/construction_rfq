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
import 'memory_catalog_search_repository.dart';

/// Tries Firestore catalog search, then falls back to the demo in-memory slice.
class FallbackCatalogSearchRepository implements CatalogSearchRepository {
  FallbackCatalogSearchRepository({
    CatalogSearchRepository? primary,
    CatalogSearchRepository? fallback,
  })  : _primary = primary ?? FirestoreCatalogSearchRepository(),
        _fallback = fallback ?? DemoCatalogSearchData.repository();

  final CatalogSearchRepository _primary;
  final CatalogSearchRepository _fallback;

  bool _preferFallback = false;

  /// True when reads are served from the demo slice (not live Firestore catalog).
  bool get usingFallback => _preferFallback || AppMode.isDemoMode;

  Future<T> _run<T>(
    Future<T> Function(CatalogSearchRepository repo) read,
  ) async {
    if (AppMode.isDemoMode || _preferFallback) {
      _preferFallback = true;
      return read(_fallback);
    }

    try {
      return await read(_primary);
    } catch (e, st) {
      _preferFallback = true;
      if (kDebugMode) {
        debugPrint(
          '[CatalogSearch] Firestore catalog unavailable, using demo slice: $e\n$st',
        );
      }
      return read(_fallback);
    }
  }

  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    if (AppMode.isDemoMode) {
      _preferFallback = true;
      return _fallback.getCategoryTree();
    }

    try {
      final categories = await _primary.getCategoryTree();
      if (categories.isEmpty) {
        _preferFallback = true;
        if (kDebugMode) {
          debugPrint(
            '[CatalogSearch] Firestore category tree empty, using demo slice',
          );
        }
        return _fallback.getCategoryTree();
      }
      return categories;
    } catch (e, st) {
      _preferFallback = true;
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
      _run((repo) => repo.getVariantById(variantId));

  @override
  Future<CatalogProduct?> getProductById(String productId) =>
      _run((repo) => repo.getProductById(productId));

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) =>
      _run((repo) => repo.searchVariants(query));

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(
    CatalogSearchQuery query,
  ) =>
      _run((repo) => repo.browseVariantsByCategory(query));
}
