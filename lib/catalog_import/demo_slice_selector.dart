import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import 'catalog_etl.dart';
import 'catalog_variant_search_fields.dart';
import 'source_models.dart';

/// Selects a bounded demo subset for validation and test imports.
class DemoSliceSelector {
  DemoSliceSelector({
    required this.categoryLimit,
    required this.productLimit,
    required this.variantLimit,
  });

  final int categoryLimit;
  final int productLimit;
  final int variantLimit;

  DemoSliceResult select({
    required Map<int, CatalogCategory> allCategories,
    required List<SourceProduct> sourceProducts,
    required List<SourceVariant> sourceVariants,
    required CatalogEtl etl,
  }) {
    final activeProducts = sourceProducts.where((p) => p.isActive).toList();

    final selectedProducts = <CatalogProduct>[];
    final selectedProductIds = <String>{};
    final selectedCategoryIds = <int>{};

    for (final sp in activeProducts) {
      if (selectedProducts.length >= productLimit) break;
      if (sp.categoryIds.isEmpty) continue;

      final needed = _categoryClosure(sp.categoryIds, allCategories);
      final merged = {...selectedCategoryIds, ...needed};
      if (merged.length > categoryLimit) continue;

      final product = etl.toProduct(sp);
      selectedProducts.add(product);
      selectedProductIds.add(product.id);
      selectedCategoryIds.addAll(needed);
    }

    final selectedCategories = selectedCategoryIds
        .map((id) => allCategories[id])
        .whereType<CatalogCategory>()
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final selectedVariants = <CatalogVariant>[];
    var order = 0;

    for (final sp in activeProducts) {
      if (!selectedProductIds.contains(sp.id.toString())) continue;
      for (final embedded in sp.embeddedVariants) {
        if (selectedVariants.length >= variantLimit) break;
        selectedVariants.add(
          etl.variantFromEmbedded(embedded, sp.id.toString(), order++),
        );
      }
    }

    for (final sv in sourceVariants) {
      if (selectedVariants.length >= variantLimit) break;
      for (final pid in sv.productIds) {
        if (!selectedProductIds.contains(pid.toString())) continue;
        selectedVariants.add(
          etl.toVariant(sv, productId: pid.toString(), sortOrder: order++),
        );
        break;
      }
    }

    final productById = {for (final p in selectedProducts) p.id: p};
    final enriched = selectedVariants
        .take(variantLimit)
        .map(
          (v) => CatalogVariantSearchFields.enrich(
            v,
            productById[v.productId],
          ),
        )
        .toList();

    return DemoSliceResult(
      categories: selectedCategories,
      products: selectedProducts,
      variants: enriched,
    );
  }

  /// Category ids on the product plus every ancestor on the path.
  Set<int> _categoryClosure(
    List<int> productCategoryIds,
    Map<int, CatalogCategory> allCategories,
  ) {
    final out = <int>{};
    for (final cid in productCategoryIds) {
      final cat = allCategories[cid];
      if (cat == null) {
        out.add(cid);
        continue;
      }
      for (final pathId in cat.pathIds) {
        final parsed = int.tryParse(pathId);
        if (parsed != null) out.add(parsed);
      }
    }
    return out;
  }
}

class DemoSliceResult {
  const DemoSliceResult({
    required this.categories,
    required this.products,
    required this.variants,
  });

  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;
  final List<CatalogVariant> variants;
}
