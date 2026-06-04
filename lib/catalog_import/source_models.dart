/// Raw records from normalized JSONL (pre-ETL).
class SourceCategoryNode {
  SourceCategoryNode({
    required this.id,
    required this.name,
    this.parentId,
    this.hasProducts = false,
    this.children = const [],
  });

  final int id;
  final String name;
  final int? parentId;
  final bool hasProducts;
  final List<SourceCategoryNode> children;

  factory SourceCategoryNode.fromJson(Map<String, dynamic> json) {
    final childrenRaw = json['children'];
    final children = childrenRaw is List
        ? childrenRaw
            .map((e) => SourceCategoryNode.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList()
        : <SourceCategoryNode>[];

    return SourceCategoryNode(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      parentId: json['parentId'] as int?,
      hasProducts: json['hasProducts'] == true,
      children: children,
    );
  }
}

class SourceProduct {
  SourceProduct({required this.raw});

  final Map<String, dynamic> raw;

  int get id => raw['id'] as int;
  String get name => raw['name'] as String? ?? '';
  bool get isActive => raw['isActive'] != false;
  List<int> get categoryIds =>
      (raw['categoryIds'] as List?)?.map((e) => e as int).toList() ?? [];
  List<String> get aka =>
      (raw['aka'] as List?)?.map((e) => e.toString()).toList() ?? [];
  String? get primaryImage => raw['primaryImage'] as String?;
  List<Map<String, dynamic>> get embeddedVariants =>
      (raw['variants'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];
}

class SourceVariant {
  SourceVariant({required this.raw});

  final Map<String, dynamic> raw;

  int get id => raw['id'] as int;
  String get name => raw['name'] as String? ?? '';
  String? get image => raw['image'] as String?;
  String get status => raw['status'] as String? ?? 'Active';
  List<int> get productIds =>
      (raw['productIds'] as List?)?.map((e) => e as int).toList() ?? [];
}

class SourceImageMapEntry {
  SourceImageMapEntry({
    required this.localFile,
    this.sha256,
    this.sizeBytes,
  });

  final String localFile;
  final String? sha256;
  final int? sizeBytes;

  factory SourceImageMapEntry.fromJson(Map<String, dynamic> json) {
    return SourceImageMapEntry(
      localFile: json['local_file'] as String? ?? '',
      sha256: json['sha256'] as String?,
      sizeBytes: json['size_bytes'] as int?,
    );
  }
}
