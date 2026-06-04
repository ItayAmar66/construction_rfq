/// Hierarchical catalog category (Firestore `catalogCategories`).
class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.pathIds = const [],
    this.pathNames = const [],
    this.depth = 0,
    this.hasProducts = false,
    this.sortOrder = 0,
    this.productCount = 0,
    this.isActive = true,
    this.nameLower = '',
  });

  final String id;
  final String name;
  final String? parentId;
  final List<String> pathIds;
  final List<String> pathNames;
  final int depth;
  final bool hasProducts;
  final int sortOrder;
  final int productCount;
  final bool isActive;
  final String nameLower;

  bool get isRoot => parentId == null || parentId!.isEmpty;

  String get breadcrumb => pathNames.isEmpty ? name : pathNames.join(' › ');

  CatalogCategory copyWith({
    String? name,
    List<String>? pathIds,
    List<String>? pathNames,
    int? depth,
    bool? hasProducts,
    int? sortOrder,
    int? productCount,
    bool? isActive,
    String? nameLower,
  }) {
    return CatalogCategory(
      id: id,
      name: name ?? this.name,
      parentId: parentId,
      pathIds: pathIds ?? this.pathIds,
      pathNames: pathNames ?? this.pathNames,
      depth: depth ?? this.depth,
      hasProducts: hasProducts ?? this.hasProducts,
      sortOrder: sortOrder ?? this.sortOrder,
      productCount: productCount ?? this.productCount,
      isActive: isActive ?? this.isActive,
      nameLower: nameLower ?? this.nameLower,
    );
  }
}
