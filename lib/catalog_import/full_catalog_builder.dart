import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import 'catalog_etl.dart';
import 'catalog_variant_search_fields.dart';
import 'dataset_loader.dart';
import 'import_config.dart';

/// Builds the complete catalog payload for full import / dry-run planning.
class FullCatalogBuilder {
  FullCatalogBuilder({
    required this.config,
    required this.loader,
    required this.etl,
  });

  final CatalogImportConfig config;
  final CatalogDatasetLoader loader;
  final CatalogEtl etl;

  Future<FullCatalogPayload> build() async {
    final forest = await loader.loadCategoryForest();
    final categoryIndex = CatalogEtl.buildCategoryIndex(forest);
    final categories = categoryIndex.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final products = <CatalogProduct>[];
    await for (final sp in loader.streamProducts()) {
      products.add(etl.toProduct(sp));
      if (config.maxProductRecords != null &&
          products.length >= config.maxProductRecords!) {
        break;
      }
    }

    final variants = <CatalogVariant>[];
    final seenVariantIds = <String>{};
    var order = 0;
    await for (final sv in loader.streamVariants()) {
      final id = sv.id.toString();
      if (seenVariantIds.contains(id)) continue;
      String? productId;
      for (final pid in sv.productIds) {
        productId = pid.toString();
        break;
      }
      if (productId == null) continue;
      variants.add(etl.toVariant(sv, productId: productId, sortOrder: order++));
      seenVariantIds.add(id);
      if (config.maxVariantRecords != null &&
          variants.length >= config.maxVariantRecords!) {
        break;
      }
    }

    var categoryList = categories;
    if (config.maxCategoryRecords != null) {
      categoryList = categories.take(config.maxCategoryRecords!).toList();
    }

    final productById = {for (final p in products) p.id: p};
    final enrichedVariants = variants
        .map(
          (v) => CatalogVariantSearchFields.enrich(
            v,
            productById[v.productId],
          ),
        )
        .toList();

    return FullCatalogPayload(
      categories: categoryList,
      products: products,
      variants: enrichedVariants,
    );
  }
}

class FullCatalogPayload {
  const FullCatalogPayload({
    required this.categories,
    required this.products,
    required this.variants,
  });

  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;
  final List<CatalogVariant> variants;

  int get totalFirestoreWrites =>
      categories.length + products.length + variants.length + 1;
}
