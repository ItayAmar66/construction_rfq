import 'catalog_product.dart';
import 'catalog_variant.dart';

/// One RFQ-selectable catalog row (variant-centric; product context optional).
class CatalogSearchHit {
  const CatalogSearchHit({
    required this.variant,
    this.product,
    this.categoryBreadcrumb = '',
  });

  final CatalogVariant variant;
  final CatalogProduct? product;
  final String categoryBreadcrumb;

  String get displayLabel =>
      variant.displayName.isNotEmpty ? variant.displayName : variant.name;

  String get productName => product?.name ?? '';
}
