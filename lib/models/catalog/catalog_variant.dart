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

  bool get isActive => status.toLowerCase() == 'active';

  CatalogVariant copyWith({
    String? name,
    String? status,
    CatalogImage? image,
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
    );
  }
}
