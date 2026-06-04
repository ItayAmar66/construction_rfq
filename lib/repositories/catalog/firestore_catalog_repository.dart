import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/catalog/catalog_category.dart';
import '../../models/catalog/catalog_list_query.dart';
import '../../models/catalog/catalog_meta.dart';
import '../../models/catalog/catalog_page.dart';
import '../../models/catalog/catalog_product.dart';
import '../../models/catalog/catalog_variant.dart';
import '../../utils/catalog_constants.dart';
import 'catalog_firestore_converter.dart';
import 'catalog_repository.dart';

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection(CatalogConstants.categoriesCollection);

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(CatalogConstants.productsCollection);

  CollectionReference<Map<String, dynamic>> get _variants =>
      _db.collection(CatalogConstants.variantsCollection);

  DocumentReference<Map<String, dynamic>> get _metaDoc => _db
      .collection(CatalogConstants.metaCollection)
      .doc(CatalogConstants.metaCurrentDocId);

  @override
  Future<CatalogMeta> getMeta() async {
    final snap = await _metaDoc.get();
    return CatalogFirestoreConverter.metaFromDoc(snap.data());
  }

  @override
  Stream<CatalogMeta> watchMeta() {
    return _metaDoc.snapshots().map(
          (s) => CatalogFirestoreConverter.metaFromDoc(s.data()),
        );
  }

  @override
  Future<List<CatalogCategory>> loadCategories() async {
    final snap = await _categories.orderBy('sortOrder').get();
    return snap.docs
        .map((d) => CatalogFirestoreConverter.categoryFromDoc(d.id, d.data()))
        .toList();
  }

  @override
  Future<CatalogPage<CatalogProduct>> listProducts(CatalogListQuery query) async {
    Query<Map<String, dynamic>> q = _products;

    if (query.activeOnly) {
      q = q.where('isActive', isEqualTo: true);
    }

    final categoryFilter = query.primaryCategoryId ?? query.categoryId;
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      q = q.where('primaryCategoryId', isEqualTo: categoryFilter);
    } else if (query.searchToken != null && query.searchToken!.isNotEmpty) {
      q = q.where('searchTokens', arrayContains: query.searchToken);
    } else if (query.searchPrefix != null && query.searchPrefix!.isNotEmpty) {
      final prefix = query.searchPrefix!.toLowerCase();
      q = q
          .where('nameLower', isGreaterThanOrEqualTo: prefix)
          .where('nameLower', isLessThan: '$prefix\uf8ff');
    }

    q = q.orderBy('nameLower');

    if (query.startAfterNameLower != null &&
        query.startAfterNameLower!.isNotEmpty) {
      final cursorSnap = await _products
          .where('nameLower', isEqualTo: query.startAfterNameLower)
          .limit(1)
          .get();
      if (cursorSnap.docs.isNotEmpty) {
        q = q.startAfterDocument(cursorSnap.docs.first);
      }
    }

    final limit = query.limit.clamp(1, 50);
    final snap = await q.limit(limit + 1).get();

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    final items = pageDocs
        .map((d) => CatalogFirestoreConverter.productFromDoc(d.id, d.data()))
        .toList();

    String? nextCursor;
    if (hasMore && pageDocs.isNotEmpty) {
      final last = pageDocs.last;
      nextCursor = '${last.data()['nameLower']}|${last.id}';
    }

    return CatalogPage(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  @override
  Future<CatalogProduct?> getProduct(String productId) async {
    final snap = await _products.doc(productId).get();
    if (!snap.exists) return null;
    return CatalogFirestoreConverter.productFromDoc(snap.id, snap.data()!);
  }

  @override
  Future<List<CatalogVariant>> getVariantsForProduct(
    String productId, {
    bool activeOnly = true,
  }) async {
    final snap = await _variants
        .where('productId', isEqualTo: productId)
        .orderBy('sortOrder')
        .get();

    var list = snap.docs
        .map((d) => CatalogFirestoreConverter.variantFromDoc(d.id, d.data()))
        .toList();

    if (activeOnly) {
      list = list.where((v) => v.isActive).toList();
    }
    return list;
  }

  @override
  Future<CatalogVariant?> getVariant(String variantId) async {
    final snap = await _variants.doc(variantId).get();
    if (!snap.exists) return null;
    return CatalogFirestoreConverter.variantFromDoc(snap.id, snap.data()!);
  }
}
