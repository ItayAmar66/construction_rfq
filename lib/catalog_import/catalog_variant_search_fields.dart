import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import '../utils/catalog_constants.dart';
import 'catalog_text_utils.dart';

/// Denormalized search fields for [catalogVariants] (import + Firestore MVP).
abstract final class CatalogVariantSearchFields {
  static CatalogVariant enrich(
    CatalogVariant variant,
    CatalogProduct? product,
  ) {
    final displayName = _displayName(variant, product);
    final sku = product?.sku ?? '';
    final categoryIds = product?.categoryIds ?? const <String>[];
    final primaryCategoryId = product?.primaryCategoryId ?? '';
    final pathText = product?.categoryPathNames.join(' › ') ?? '';

    final aliases = <String>[
      ...?product?.aka,
      if (variant.color != null && variant.color!.isNotEmpty) variant.color!,
      if (variant.sizeLabel.isNotEmpty) variant.sizeLabel,
    ];

    return CatalogVariant(
      id: variant.id,
      productId: variant.productId,
      name: variant.name,
      color: variant.color,
      sizeLabel: variant.sizeLabel,
      status: variant.status,
      sortOrder: variant.sortOrder,
      image: variant.image,
      nameLower: variant.nameLower.isNotEmpty
          ? variant.nameLower
          : CatalogTextUtils.normalizeForSearch(variant.name),
      legacyKey: variant.legacyKey,
      displayName: displayName,
      displayNameLower: CatalogTextUtils.normalizeForSearch(displayName),
      skuLower: CatalogTextUtils.normalizeForSearch(sku),
      categoryIds: categoryIds,
      primaryCategoryId: primaryCategoryId,
      categoryPathText: pathText,
      searchTokens: buildVariantSearchTokens(
        variantName: variant.name,
        displayName: displayName,
        sku: sku,
        productName: product?.name ?? '',
        aliases: aliases,
        categoryPathText: pathText,
      ),
      searchAliases: aliases,
      isActiveInIndex: variant.isActive,
    );
  }

  static String _displayName(CatalogVariant variant, CatalogProduct? product) {
    final parts = <String>[];
    if (product != null && product.name.isNotEmpty) {
      parts.add(product.name);
    }
    if (variant.name.isNotEmpty &&
        (product == null || variant.name != product.name)) {
      parts.add(variant.name);
    }
    if (parts.isEmpty) return variant.name;
    return parts.join(' — ');
  }

  static List<String> buildVariantSearchTokens({
    required String variantName,
    required String displayName,
    String sku = '',
    String productName = '',
    List<String> aliases = const [],
    String categoryPathText = '',
    int maxTokens = CatalogConstants.maxSearchTokens,
  }) {
    final tokens = <String>{};

    void absorb(String text) {
      for (final t in CatalogTextUtils.buildSearchTokens(name: text, maxTokens: maxTokens)) {
        tokens.add(t);
      }
    }

    absorb(variantName);
    if (displayName != variantName) absorb(displayName);
    if (productName.isNotEmpty) absorb(productName);
    if (sku.isNotEmpty) {
      absorb(sku);
      tokens.add(CatalogTextUtils.normalizeForSearch(sku));
    }
    for (final a in aliases) {
      absorb(a);
    }
    if (categoryPathText.isNotEmpty) absorb(categoryPathText);

    return tokens.take(maxTokens).toList();
  }
}
