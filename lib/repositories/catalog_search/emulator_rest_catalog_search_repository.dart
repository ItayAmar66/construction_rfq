import '../../catalog_import/emulator_rest_firestore_backend.dart';
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
import 'firestore_rest_structured_query_encoder.dart';

/// VM-safe catalog search against the Firestore emulator via REST `:runQuery`.
///
/// Same [CatalogSearchRepository] contract as [FirestoreCatalogSearchRepository]
/// but uses [EmulatorRestFirestoreBackend] (no FirebaseCore / cloud_firestore).
class EmulatorRestCatalogSearchRepository implements CatalogSearchRepository {
  EmulatorRestCatalogSearchRepository({
    EmulatorRestFirestoreBackend? backend,
  }) : _backend = backend ??
            EmulatorRestFirestoreBackend(
              projectId: EmulatorRestFirestoreBackend.defaultProjectId,
              emulatorMode: true,
            );

  final EmulatorRestFirestoreBackend _backend;

  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    final all = <CatalogCategory>[];
    String? pageToken;
    do {
      final page = await _backend.listCollectionPage(
        CatalogConstants.categoriesCollection,
        pageSize: 500,
        pageToken: pageToken,
      );
      for (final doc in page.docs) {
        all.add(CatalogFirestoreConverter.categoryFromDoc(doc.key, doc.value));
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    all.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return all;
  }

  @override
  Future<CatalogVariant?> getVariantById(String variantId) async {
    final data = await _backend.getDocument(
      CatalogConstants.variantsCollection,
      variantId,
    );
    if (data == null) return null;
    return CatalogFirestoreConverter.variantFromDoc(variantId, data);
  }

  @override
  Future<CatalogProduct?> getProductById(String productId) async {
    final data = await _backend.getDocument(
      CatalogConstants.productsCollection,
      productId,
    );
    if (data == null) return null;
    return CatalogFirestoreConverter.productFromDoc(productId, data);
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
    final limit = query.effectiveLimit;
    final plan = FirestoreCatalogSearchQueryBuilder.plan(query);
    final body = FirestoreRestStructuredQueryEncoder.encode(
      collectionId: CatalogConstants.variantsCollection,
      plan: plan,
      limit: limit + 1,
    );

    final docs = await _backend.runStructuredQuery(body);
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    final variants = pageDocs
        .map((d) => CatalogFirestoreConverter.variantFromDoc(d.key, d.value))
        .toList();

    final hits = <CatalogSearchHit>[];
    for (final variant in variants) {
      final product = await getProductById(variant.productId);
      hits.add(
        CatalogSearchHit(
          variant: variant,
          product: product,
          categoryBreadcrumb: variant.categoryPathText,
        ),
      );
    }

    String? nextToken;
    if (hasMore && pageDocs.isNotEmpty) {
      final last = pageDocs.last;
      final orderKey = plan.orderByField == 'sortOrder'
          ? '${last.value['sortOrder'] ?? 0}'
          : (last.value[plan.orderByField] as String? ??
              last.value['nameLower'] as String? ??
              '');
      nextToken = FirestoreCatalogSearchQueryBuilder.encodePageToken(
        orderKey.toString(),
        last.key,
      );
    }

    return CatalogSearchPage(
      hits: hits,
      nextPageToken: nextToken,
      hasMore: hasMore,
    );
  }

  void close() => _backend.close();
}
