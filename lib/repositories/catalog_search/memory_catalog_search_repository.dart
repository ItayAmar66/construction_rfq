import '../../catalog_import/catalog_text_utils.dart';
import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_search_hit.dart';
import '../../models/catalog/catalog_search_page.dart';
import '../../models/catalog/catalog_search_query.dart';
import '../../models/catalog/catalog_variant.dart';
import 'catalog_search_repository.dart';

/// In-memory variant search for unit tests (no Firestore).
class MemoryCatalogSearchRepository implements CatalogSearchRepository {
  MemoryCatalogSearchRepository({
    List<CatalogCategory>? categories,
    List<CatalogProduct>? products,
    List<CatalogVariant>? variants,
  })  : _categories = List.of(categories ?? const []),
        _products = List.of(products ?? const []),
        _variants = List.of(variants ?? const []);

  final List<CatalogCategory> _categories;
  final List<CatalogProduct> _products;
  final List<CatalogVariant> _variants;

  Map<String, CatalogProduct> get _productById => {
        for (final p in _products) p.id: p,
      };

  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    final list = List<CatalogCategory>.from(_categories);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<CatalogVariant?> getVariantById(String variantId) async {
    try {
      return _variants.firstWhere((v) => v.id == variantId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CatalogProduct?> getProductById(String productId) async {
    return _productById[productId];
  }

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) async {
    return _page(_filter(query), query);
  }

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(
    CatalogSearchQuery query,
  ) async {
    if (!query.hasCategory) {
      return CatalogSearchPage.empty;
    }
    return _page(_filter(query), query);
  }

  List<CatalogVariant> _filter(CatalogSearchQuery query) {
    final normalized = query.hasText
        ? CatalogTextUtils.normalizeForSearch(query.text!)
        : '';
    final tokens = normalized.isEmpty
        ? const <String>[]
        : CatalogTextUtils.buildSearchTokens(name: normalized, maxTokens: 5);

    return _variants.where((v) {
      if (!query.includeInactive && !v.isActive) return false;

      if (query.hasCategory) {
        final cat = query.categoryId!.trim();
        if (!v.categoryIds.contains(cat) && v.primaryCategoryId != cat) {
          return false;
        }
      }

      if (normalized.isEmpty) return true;

      if (v.skuLower.isNotEmpty && v.skuLower.startsWith(normalized)) {
        return true;
      }
      if (v.displayNameLower.startsWith(normalized) ||
          v.nameLower.startsWith(normalized)) {
        return true;
      }
      for (final t in tokens) {
        if (v.searchTokens.contains(t)) return true;
      }
      return false;
    }).toList()
      ..sort((a, b) {
        if (normalized.isNotEmpty) {
          final rankA = _searchRank(a, normalized, tokens);
          final rankB = _searchRank(b, normalized, tokens);
          final rankCmp = rankA.compareTo(rankB);
          if (rankCmp != 0) return rankCmp;
        }
        if (query.sort == CatalogSearchSort.sortOrder) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          if (c != 0) return c;
        }
        return a.displayNameLower.compareTo(b.displayNameLower);
      });
  }

  int _searchRank(
    CatalogVariant variant,
    String normalized,
    List<String> tokens,
  ) {
    if (variant.skuLower == normalized) return 0;
    if (variant.skuLower.startsWith(normalized)) return 1;
    if (tokens.any((t) => variant.searchTokens.contains(t))) return 2;
    if (variant.displayNameLower.startsWith(normalized) ||
        variant.nameLower.startsWith(normalized)) {
      return 3;
    }
    return 4;
  }

  Future<CatalogSearchPage> _page(
    List<CatalogVariant> filtered,
    CatalogSearchQuery query,
  ) async {
    var list = filtered;
    final cursor = query.pageToken;
    if (cursor != null && cursor.isNotEmpty) {
      final parts = cursor.split('|');
      if (parts.length >= 2) {
        final id = parts[1];
        final idx = list.indexWhere((v) => v.id == id);
        if (idx >= 0) list = list.sublist(idx + 1);
      }
    }

    final limit = query.effectiveLimit;
    final hasMore = list.length > limit;
    final page = hasMore ? list.sublist(0, limit) : list;

    final productById = _productById;
    final hits = page
        .map(
          (v) => CatalogSearchHit(
            variant: v,
            product: productById[v.productId],
            categoryBreadcrumb: v.categoryPathText,
          ),
        )
        .toList();

    String? next;
    if (hasMore && page.isNotEmpty) {
      final last = page.last;
      final key = query.sort == CatalogSearchSort.sortOrder
          ? '${last.sortOrder}'
          : last.displayNameLower.isNotEmpty
              ? last.displayNameLower
              : last.nameLower;
      next = '$key|${last.id}';
    }

    return CatalogSearchPage(
      hits: hits,
      nextPageToken: next,
      hasMore: hasMore,
    );
  }
}
