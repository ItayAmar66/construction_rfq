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

  factory Product.fromMap(String id, Map<String, dynamic> map) {
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
    };
  }
}
