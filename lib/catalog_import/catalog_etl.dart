import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_image.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import '../utils/catalog_constants.dart';
import 'catalog_text_utils.dart';
import 'source_models.dart' show SourceCategoryNode, SourceImageMapEntry, SourceProduct, SourceVariant;

/// Transforms source JSON into Firestore-ready catalog domain models.
class CatalogEtl {
  CatalogEtl({
    required this.categoryById,
    this.imageMap = const {},
  });

  final Map<int, CatalogCategory> categoryById;
  final Map<String, SourceImageMapEntry> imageMap;

  static Map<int, CatalogCategory> buildCategoryIndex(
    List<SourceCategoryNode> forest,
  ) {
    final byId = <int, SourceCategoryNode>{};

    void indexNodes(List<SourceCategoryNode> nodes, int? parentId) {
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        byId[node.id] = SourceCategoryNode(
          id: node.id,
          name: node.name,
          parentId: parentId ?? node.parentId,
          hasProducts: node.hasProducts,
          children: node.children,
        );
        indexNodes(node.children, node.id);
      }
    }

    indexNodes(forest, null);

    final result = <int, CatalogCategory>{};
    for (final entry in byId.entries) {
      final paths = _resolvePaths(entry.key, byId);
      result[entry.key] = CatalogCategory(
        id: entry.key.toString(),
        name: entry.value.name,
        parentId: entry.value.parentId?.toString(),
        pathIds: paths.ids,
        pathNames: paths.names,
        depth: paths.ids.length - 1,
        hasProducts: entry.value.hasProducts,
        sortOrder: entry.key,
        nameLower: entry.value.name.toLowerCase(),
      );
    }
    return result;
  }

  static _CategoryPaths _resolvePaths(
    int id,
    Map<int, SourceCategoryNode> byId,
  ) {
    final ids = <String>[];
    final names = <String>[];
    var current = id;
    final guard = <int>{};
    while (byId.containsKey(current) && !guard.contains(current)) {
      guard.add(current);
      final node = byId[current]!;
      ids.insert(0, current.toString());
      names.insert(0, node.name);
      final parent = node.parentId;
      if (parent == null) break;
      current = parent;
    }
    return _CategoryPaths(ids: ids, names: names);
  }

  CatalogProduct toProduct(SourceProduct source) {
    final id = source.id.toString();
    final categoryIds =
        source.categoryIds.map((c) => c.toString()).toList();
    final primaryId =
        categoryIds.isNotEmpty ? categoryIds.first : '';
    final paths = categoryById[int.tryParse(primaryId) ?? -1];

    final attrs = source.raw['attributes'] as List? ?? [];
    final specs = <String, String>{};
    String? html;
    for (final a in attrs) {
      if (a is! Map) continue;
      final title = a['attribute']?.toString() ?? '';
      final desc = a['description']?.toString() ?? '';
      if (title.isEmpty) continue;
      if (title.contains('תיאור') && html == null) {
        html = desc;
      }
      specs[title] = CatalogTextUtils.stripHtml(desc);
    }

    final embedded = source.embeddedVariants;
    final defaultVariant = embedded.isNotEmpty ? embedded.first : null;
    final legacyVariant = defaultVariant?['name']?.toString() ?? '';

    final size = source.raw['size'] as Map<String, dynamic>?;
    final image = _imageFromPath(source.primaryImage);

    return CatalogProduct(
      id: id,
      name: source.name.trim(),
      aka: source.aka,
      searchTokens: CatalogTextUtils.buildSearchTokens(
        name: source.name,
        aka: source.aka,
        maxTokens: CatalogConstants.maxSearchTokens,
      ),
      categoryIds: categoryIds,
      primaryCategoryId: primaryId,
      categoryPathNames: paths?.pathNames ?? const [],
      unitType: CatalogTextUtils.unitFromSize(size),
      packagingLabel: CatalogTextUtils.packagingFromSize(size),
      descriptionPlain: html != null ? CatalogTextUtils.stripHtml(html) : '',
      descriptionHtml: html,
      specs: specs,
      isActive: source.isActive,
      variantCount: embedded.length,
      defaultVariantId: defaultVariant?['id']?.toString(),
      image: image,
      nameLower: CatalogTextUtils.normalizeForSearch(source.name),
      legacyCategory: paths?.name ?? '',
      legacyVariant: legacyVariant,
    );
  }

  CatalogVariant toVariant(
    SourceVariant source, {
    required String productId,
    int sortOrder = 0,
  }) {
    final size = source.raw['size'] as Map<String, dynamic>?;
    return CatalogVariant(
      id: source.id.toString(),
      productId: productId,
      name: source.name.trim(),
      color: source.raw['color']?.toString(),
      sizeLabel: CatalogTextUtils.packagingFromSize(size),
      status: source.status,
      sortOrder: sortOrder,
      image: _imageFromPath(source.image),
      nameLower: CatalogTextUtils.normalizeForSearch(source.name),
    );
  }

  CatalogVariant variantFromEmbedded(
    Map<String, dynamic> raw,
    String productId,
    int sortOrder,
  ) {
    return CatalogVariant(
      id: raw['id'].toString(),
      productId: productId,
      name: raw['name']?.toString().trim() ?? '',
      color: raw['color']?.toString(),
      sizeLabel: CatalogTextUtils.packagingFromSize(
        raw['size'] as Map<String, dynamic>?,
      ),
      status: raw['status']?.toString() ?? 'Active',
      sortOrder: sortOrder,
      image: _imageFromPath(raw['image'] as String?),
      nameLower: CatalogTextUtils.normalizeForSearch(
        raw['name']?.toString() ?? '',
      ),
    );
  }

  CatalogImage _imageFromPath(String? localPath) {
    if (localPath == null || localPath.isEmpty) {
      return const CatalogImage();
    }
    final entry = imageMap[localPath];
    return CatalogImage(
      localPath: localPath,
      sha256: entry?.sha256,
      sizeBytes: entry?.sizeBytes,
    );
  }
}

class _CategoryPaths {
  const _CategoryPaths({required this.ids, required this.names});
  final List<String> ids;
  final List<String> names;
}
