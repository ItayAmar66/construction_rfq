import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_list_query.dart';
import '../../models/catalog/catalog_meta.dart';
import '../../models/catalog/catalog_page.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_variant.dart';
import 'catalog_repository.dart';

/// In-memory catalog for unit tests and offline validation (no Firestore).
class MemoryCatalogRepository implements CatalogRepository {
  MemoryCatalogRepository({
    CatalogMeta? meta,
    List<CatalogCategory>? categories,
    List<CatalogProduct>? products,
    List<CatalogVariant>? variants,
  })  : _meta = meta ?? const CatalogMeta(version: 'memory'),
        _categories = List.of(categories ?? const []),
        _products = List.of(products ?? const []),
        _variants = List.of(variants ?? const []);

  final CatalogMeta _meta;
  final List<CatalogCategory> _categories;
  final List<CatalogProduct> _products;
  final List<CatalogVariant> _variants;

  @override
  Future<CatalogMeta> getMeta() async => _meta;

  @override
  Stream<CatalogMeta> watchMeta() async* {
    yield _meta;
  }

  @override
  Future<List<CatalogCategory>> loadCategories() async {
    final list = List<CatalogCategory>.from(_categories);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<CatalogPage<CatalogProduct>> listProducts(CatalogListQuery query) async {
    var list = _products.where((p) {
      if (query.activeOnly && !p.isActive) return false;
      final cat = query.primaryCategoryId ?? query.categoryId;
      if (cat != null &&
          cat.isNotEmpty &&
          p.primaryCategoryId != cat &&
          !p.categoryIds.contains(cat)) {
        return false;
      }
      if (query.searchToken != null &&
          query.searchToken!.isNotEmpty &&
          !p.searchTokens.contains(query.searchToken)) {
        return false;
      }
      if (query.searchPrefix != null && query.searchPrefix!.isNotEmpty) {
        final prefix = query.searchPrefix!.toLowerCase();
        if (!p.nameLower.startsWith(prefix)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) => a.nameLower.compareTo(b.nameLower));

    if (query.startAfterNameLower != null && query.startAfterId != null) {
      final idx = list.indexWhere(
        (p) => p.id == query.startAfterId,
      );
      if (idx >= 0) {
        list = list.sublist(idx + 1);
      }
    }

    final limit = query.limit.clamp(1, 50);
    final hasMore = list.length > limit;
    final page = hasMore ? list.sublist(0, limit) : list;
    final next = hasMore && page.isNotEmpty
        ? '${page.last.nameLower}|${page.last.id}'
        : null;

    return CatalogPage(
      items: page,
      nextCursor: next,
      hasMore: hasMore,
    );
  }

  @override
  Future<CatalogProduct?> getProduct(String productId) async {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CatalogVariant>> getVariantsForProduct(
    String productId, {
    bool activeOnly = true,
  }) async {
    return _variants
        .where((v) {
          if (v.productId != productId) return false;
          if (activeOnly && !v.isActive) return false;
          return true;
        })
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<CatalogVariant?> getVariant(String variantId) async {
    try {
      return _variants.firstWhere((v) => v.id == variantId);
    } catch (_) {
      return null;
    }
  }
}
