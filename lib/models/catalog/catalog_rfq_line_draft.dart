import 'catalog_search_hit.dart';

/// Draft RFQ line from catalog variant selection (not persisted until RFQ cutover).
class CatalogRfqLineDraft {
  const CatalogRfqLineDraft({
    required this.variantId,
    required this.productId,
    required this.categoryId,
    required this.categoryPath,
    required this.displayName,
    this.productName = '',
    this.variantName = '',
    this.sku = '',
    this.unitType = '',
    this.packagingLabel = '',
    this.imagePath,
    this.attributesSnapshot = const {},
    this.sourceCatalogVersion,
    this.quantity = 1,
    this.notes = '',
    this.isCatalogMatched = true,
  });

  final String variantId;
  final String productId;
  final String categoryId;
  final String categoryPath;
  final String displayName;
  final String productName;
  final String variantName;
  final String sku;
  final String unitType;
  final String packagingLabel;
  final String? imagePath;
  final Map<String, String> attributesSnapshot;
  final String? sourceCatalogVersion;
  final int quantity;
  final String notes;
  final bool isCatalogMatched;

  factory CatalogRfqLineDraft.fromSearchHit(CatalogSearchHit hit) {
    final variant = hit.variant;
    final product = hit.product;
    final categoryId = variant.primaryCategoryId.isNotEmpty
        ? variant.primaryCategoryId
        : (variant.categoryIds.isNotEmpty ? variant.categoryIds.first : '');
    final categoryPath = hit.categoryBreadcrumb.isNotEmpty
        ? hit.categoryBreadcrumb
        : (product?.categoryPathNames.join(' › ') ?? '');
    final imagePath = variant.image.thumbUrl ??
        variant.image.url ??
        variant.image.localPath ??
        product?.image.thumbUrl ??
        product?.image.url ??
        product?.image.localPath;

    return CatalogRfqLineDraft(
      variantId: variant.id,
      productId: variant.productId,
      categoryId: categoryId,
      categoryPath: categoryPath,
      displayName: hit.displayLabel,
      productName: product?.name ?? hit.displayLabel,
      variantName: variant.name,
      sku: product?.sku ?? '',
      unitType: product?.unitType ?? '',
      packagingLabel: product?.packagingLabel.isNotEmpty == true
          ? product!.packagingLabel
          : variant.sizeLabel,
      imagePath: imagePath,
      attributesSnapshot: product?.specs ?? const {},
      quantity: 1,
      notes: '',
      isCatalogMatched: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'variantId': variantId,
        'productId': productId,
        'categoryId': categoryId,
        'categoryPath': categoryPath,
        'displayName': displayName,
        if (productName.isNotEmpty) 'productName': productName,
        if (variantName.isNotEmpty) 'variantName': variantName,
        'sku': sku,
        'unitType': unitType,
        'packagingLabel': packagingLabel,
        if (imagePath != null && imagePath!.isNotEmpty) 'imagePath': imagePath,
        if (attributesSnapshot.isNotEmpty)
          'attributesSnapshot': attributesSnapshot,
        if (sourceCatalogVersion != null && sourceCatalogVersion!.isNotEmpty)
          'sourceCatalogVersion': sourceCatalogVersion,
        'quantity': quantity,
        'notes': notes,
        'isCatalogMatched': isCatalogMatched,
      };
}
