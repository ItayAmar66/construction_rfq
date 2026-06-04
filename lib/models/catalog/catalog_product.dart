import 'catalog_image.dart';

/// Catalog product summary (Firestore `catalogProducts`).
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    this.aka = const [],
    this.searchTokens = const [],
    this.categoryIds = const [],
    this.primaryCategoryId = '',
    this.categoryPathNames = const [],
    this.brand = '',
    this.sku = '',
    this.unitType = '',
    this.packagingLabel = '',
    this.descriptionPlain = '',
    this.descriptionHtml,
    this.specs = const {},
    this.isActive = true,
    this.variantCount = 0,
    this.defaultVariantId,
    this.image = const CatalogImage(),
    this.relatedProductIds = const [],
    this.nameLower = '',
    this.legacyCategory = '',
    this.legacyVariant = '',
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> aka;
  final List<String> searchTokens;
  final List<String> categoryIds;
  final String primaryCategoryId;
  final List<String> categoryPathNames;
  final String brand;
  final String sku;
  final String unitType;
  final String packagingLabel;
  final String descriptionPlain;
  final String? descriptionHtml;
  final Map<String, String> specs;
  final bool isActive;
  final int variantCount;
  final String? defaultVariantId;
  final CatalogImage image;
  final List<String> relatedProductIds;
  final String nameLower;
  final String legacyCategory;
  final String legacyVariant;
  final DateTime? updatedAt;

  String get displayCategory =>
      categoryPathNames.isNotEmpty ? categoryPathNames.last : legacyCategory;

  /// Maps to legacy [Product] for RFQ/cart compatibility (no UI wiring yet).
  Map<String, dynamic> toLegacyProductMap() => {
        'name': name,
        'category': legacyCategory.isNotEmpty ? legacyCategory : displayCategory,
        'variant': legacyVariant,
        'unitType': unitType,
        'description': descriptionPlain,
        'imageUrl': image.url ?? image.thumbUrl,
        'brand': brand,
        'sku': sku,
        'specs': specs,
        'packagingLabel': packagingLabel,
        'relatedProductIds': relatedProductIds,
      };
}
