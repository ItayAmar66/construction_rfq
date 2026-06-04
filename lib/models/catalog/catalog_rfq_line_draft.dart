import 'catalog_search_hit.dart';

/// Draft RFQ line from catalog variant selection (not persisted until RFQ cutover).
class CatalogRfqLineDraft {
  const CatalogRfqLineDraft({
    required this.variantId,
    required this.productId,
    required this.categoryId,
    required this.categoryPath,
    required this.displayName,
    this.sku = '',
    this.unitType = '',
    this.packagingLabel = '',
    this.quantity = 1,
    this.notes = '',
    this.isCatalogMatched = true,
  });

  final String variantId;
  final String productId;
  final String categoryId;
  final String categoryPath;
  final String displayName;
  final String sku;
  final String unitType;
  final String packagingLabel;
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

    return CatalogRfqLineDraft(
      variantId: variant.id,
      productId: variant.productId,
      categoryId: categoryId,
      categoryPath: categoryPath,
      displayName: hit.displayLabel,
      sku: product?.sku ?? '',
      unitType: product?.unitType ?? '',
      packagingLabel: product?.packagingLabel.isNotEmpty == true
          ? product!.packagingLabel
          : variant.sizeLabel,
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
        'sku': sku,
        'unitType': unitType,
        'packagingLabel': packagingLabel,
        'quantity': quantity,
        'notes': notes,
        'isCatalogMatched': isCatalogMatched,
      };
}
