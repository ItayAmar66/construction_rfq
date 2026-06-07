import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/catalog/catalog_availability.dart';
import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_search_hit.dart';
import '../../models/catalog/catalog_search_page.dart';
import '../../models/catalog/catalog_search_query.dart';
import '../../models/catalog/catalog_variant.dart';
import '../../utils/catalog_constants.dart';
import '../catalog/catalog_firestore_converter.dart';
import 'catalog_search_repository.dart';
import 'firestore_catalog_search_query_builder.dart';

class FirestoreCatalogSearchRepository implements CatalogSearchRepository {
  FirestoreCatalogSearchRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _variants =>
      _db.collection(CatalogConstants.variantsCollection);

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(CatalogConstants.productsCollection);

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection(CatalogConstants.categoriesCollection);

  CollectionReference<Map<String, dynamic>> get _meta =>
      _db.collection(CatalogConstants.metaCollection);

  @override
  Future<CatalogAvailability> getCatalogAvailability() async {
    final snap = await _meta.doc(CatalogConstants.metaCurrentDocId).get();
    if (!snap.exists) {
      final variantSample = await _variants
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (variantSample.docs.isNotEmpty) {
        return CatalogAvailability.partialWithData(
          reason: 'partial_import',
        );
      }
      return CatalogAvailability.unavailable(reason: 'missing_meta');
    }
    final meta = CatalogFirestoreConverter.metaFromDoc(snap.data());
    return CatalogAvailability.fromMeta(meta, hasDoc: true);
  }

  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    final snap = await _categories.orderBy('sortOrder').get();
    return snap.docs
        .map((d) => CatalogFirestoreConverter.categoryFromDoc(d.id, d.data()))
        .toList();
  }

  @override
  Future<CatalogVariant?> getVariantById(String variantId) async {
    final snap = await _variants.doc(variantId).get();
    if (!snap.exists) return null;
    return CatalogFirestoreConverter.variantFromDoc(snap.id, snap.data()!);
  }

  @override
  Future<CatalogProduct?> getProductById(String productId) async {
    final snap = await _products.doc(productId).get();
    if (!snap.exists) return null;
    return CatalogFirestoreConverter.productFromDoc(snap.id, snap.data()!);
  }

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) async {
    return _queryVariants(query);
  }

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(
    CatalogSearchQuery query,
  ) async {
    if (!query.hasCategory) return CatalogSearchPage.empty;
    return _queryVariants(query);
  }

  Future<CatalogSearchPage> _queryVariants(CatalogSearchQuery query) async {
    final plan = FirestoreCatalogSearchQueryBuilder.plan(query);
    Query<Map<String, dynamic>> q =
        FirestoreCatalogSearchQueryBuilder.apply(_variants, plan);

    final cursor = FirestoreCatalogSearchQueryBuilder.parsePageToken(
      query.pageToken,
    );
    if (cursor.docId != null) {
      final cursorSnap = await _variants.doc(cursor.docId).get();
      if (cursorSnap.exists) {
        q = q.startAfterDocument(cursorSnap);
      }
    }

    final limit = query.effectiveLimit;
    final fetchLimit =
        plan.scopeCategoryId != null ? (limit + 1) * 4 : limit + 1;
    final snap = await q.limit(fetchLimit.clamp(limit + 1, 200)).get();
    final docs = snap.docs;

    var pageDocs = docs;
    if (plan.scopeCategoryId != null) {
      pageDocs = docs
          .where((d) {
            final data = d.data();
            final ids = data['categoryIds'];
            if (ids is! List) return false;
            return ids.map((e) => e.toString()).contains(plan.scopeCategoryId);
          })
          .toList();
    }

    final hasMore = plan.scopeCategoryId != null
        ? docs.length >= fetchLimit.clamp(limit + 1, 200) ||
            pageDocs.length > limit
        : docs.length > limit;
    if (pageDocs.length > limit) {
      pageDocs = pageDocs.sublist(0, limit);
    } else if (plan.scopeCategoryId == null && docs.length > limit) {
      pageDocs = docs.sublist(0, limit);
    }

    final variants = pageDocs
        .map((d) => CatalogFirestoreConverter.variantFromDoc(d.id, d.data()))
        .toList();

    final productIds = variants.map((v) => v.productId).toSet();
    final products = await _loadProducts(productIds);

    final hits = variants
        .map(
          (v) => CatalogSearchHit(
            variant: v,
            product: products[v.productId],
            categoryBreadcrumb: v.categoryPathText,
          ),
        )
        .toList();

    String? nextToken;
    if (hasMore && pageDocs.isNotEmpty) {
      final last = pageDocs.last;
      final data = last.data();
      final orderKey = plan.orderByField == 'sortOrder'
          ? '${data['sortOrder'] ?? 0}'
          : (data[plan.orderByField] as String? ??
              data['nameLower'] as String? ??
              '');
      nextToken = FirestoreCatalogSearchQueryBuilder.encodePageToken(
        orderKey.toString(),
        last.id,
      );
    }

    return CatalogSearchPage(
      hits: hits,
      nextPageToken: nextToken,
      hasMore: hasMore,
    );
  }

  Future<Map<String, CatalogProduct>> _loadProducts(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final out = <String, CatalogProduct>{};
    final idList = ids.toList();
    for (var i = 0; i < idList.length; i += 10) {
      final end = i + 10 > idList.length ? idList.length : i + 10;
      final chunk = idList.sublist(i, end);
      final snap = await _products
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        out[doc.id] =
            CatalogFirestoreConverter.productFromDoc(doc.id, doc.data());
      }
    }
    return out;
  }
}
