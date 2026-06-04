import 'catalog_image.dart';

/// Purchasable variant row (Firestore `catalogVariants`).
class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.productId,
    required this.name,
    this.color,
    this.sizeLabel = '',
    this.status = 'Active',
    this.sortOrder = 0,
    this.image = const CatalogImage(),
    this.nameLower = '',
    this.legacyKey,
    this.displayName = '',
    this.displayNameLower = '',
    this.skuLower = '',
    this.categoryIds = const [],
    this.primaryCategoryId = '',
    this.categoryPathText = '',
    this.searchTokens = const [],
    this.searchAliases = const [],
    this.isActiveInIndex = true,
  });

  final String id;
  final String productId;
  final String name;
  final String? color;
  final String sizeLabel;
  final String status;
  final int sortOrder;
  final CatalogImage image;
  final String nameLower;
  final String? legacyKey;

  /// Denormalized search/browse fields (import + Firestore MVP).
  final String displayName;
  final String displayNameLower;
  final String skuLower;
  final List<String> categoryIds;
  final String primaryCategoryId;
  final String categoryPathText;
  final List<String> searchTokens;
  final List<String> searchAliases;

  /// Indexed boolean for Firestore `where('isActive', ...)`.
  final bool isActiveInIndex;

  bool get isActive => status.toLowerCase() == 'active' && isActiveInIndex;

  CatalogVariant copyWith({
    String? name,
    String? status,
    CatalogImage? image,
    bool? isActiveInIndex,
  }) {
    return CatalogVariant(
      id: id,
      productId: productId,
      name: name ?? this.name,
      color: color,
      sizeLabel: sizeLabel,
      status: status ?? this.status,
      sortOrder: sortOrder,
      image: image ?? this.image,
      nameLower: nameLower,
      legacyKey: legacyKey,
      displayName: displayName,
      displayNameLower: displayNameLower,
      skuLower: skuLower,
      categoryIds: categoryIds,
      primaryCategoryId: primaryCategoryId,
      categoryPathText: categoryPathText,
      searchTokens: searchTokens,
      searchAliases: searchAliases,
      isActiveInIndex: isActiveInIndex ?? this.isActiveInIndex,
    );
  }
}
