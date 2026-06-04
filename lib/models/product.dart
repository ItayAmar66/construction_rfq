class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.variant,
    required this.unitType,
    this.unitsPerPackage,
    this.boxesCount,
    this.litersPerBucket,
    required this.description,
    this.imageUrl,
    this.brand = '',
    this.sku = '',
    this.specs = const {},
    this.packagingLabel,
    this.relatedProductIds = const [],
  });

  final String id;
  final String name;
  final String category;
  final String variant;
  final String unitType;
  final int? unitsPerPackage;
  final int? boxesCount;
  final double? litersPerBucket;
  final String description;
  final String? imageUrl;
  final String brand;
  final String sku;
  final Map<String, String> specs;
  final String? packagingLabel;
  final List<String> relatedProductIds;

  String get packagingSummary {
    if (packagingLabel != null && packagingLabel!.isNotEmpty) {
      return packagingLabel!;
    }
    if (unitsPerPackage != null) return '$unitsPerPackage יח\' באריזה';
    if (boxesCount != null) return '$boxesCount ארגזים במשטח';
    if (litersPerBucket != null) return '$litersPerBucket ליטר בדלי';
    return unitType;
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final specsRaw = map['specs'];
    final specs = <String, String>{};
    if (specsRaw is Map) {
      specsRaw.forEach((k, v) {
        if (v != null) specs[k.toString()] = v.toString();
      });
    }
    final relatedRaw = map['relatedProductIds'];
    final related = relatedRaw is List
        ? relatedRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      variant: map['variant'] as String? ?? '',
      unitType: map['unitType'] as String? ?? '',
      unitsPerPackage: map['unitsPerPackage'] as int?,
      boxesCount: map['boxesCount'] as int?,
      litersPerBucket: (map['litersPerBucket'] as num?)?.toDouble(),
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      brand: map['brand'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      specs: specs,
      packagingLabel: map['packagingLabel'] as String?,
      relatedProductIds: related,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'variant': variant,
      'unitType': unitType,
      'unitsPerPackage': unitsPerPackage,
      'boxesCount': boxesCount,
      'litersPerBucket': litersPerBucket,
      'description': description,
      'imageUrl': imageUrl,
      if (brand.isNotEmpty) 'brand': brand,
      if (sku.isNotEmpty) 'sku': sku,
      if (specs.isNotEmpty) 'specs': specs,
      if (packagingLabel != null) 'packagingLabel': packagingLabel,
      if (relatedProductIds.isNotEmpty) 'relatedProductIds': relatedProductIds,
    };
  }
}
