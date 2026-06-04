import 'dart:convert';
import 'dart:io';

import 'import_config.dart';
import 'source_models.dart';

/// Loads normalized catalog files from disk.
class CatalogDatasetLoader {
  CatalogDatasetLoader(this.config);

  final CatalogImportConfig config;

  Future<List<SourceCategoryNode>> loadCategoryForest() async {
    final file = File(config.categoriesPath);
    final list = jsonDecode(await file.readAsString()) as List;
    return list
        .map((e) => SourceCategoryNode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<SourceCategoryNode> flattenCategories(List<SourceCategoryNode> roots) {
    final flat = <SourceCategoryNode>[];
    void walk(SourceCategoryNode node) {
      flat.add(
        SourceCategoryNode(
          id: node.id,
          name: node.name,
          parentId: node.parentId,
          hasProducts: node.hasProducts,
          children: const [],
        ),
      );
      for (final child in node.children) {
        walk(child);
      }
    }

    for (final root in roots) {
      walk(root);
    }
    return flat;
  }

  Stream<SourceProduct> streamProducts() async* {
    final file = File(config.productsPath);
    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      yield SourceProduct(raw: jsonDecode(line) as Map<String, dynamic>);
    }
  }

  Future<List<SourceProduct>> loadAllProducts() async {
    final list = <SourceProduct>[];
    await for (final p in streamProducts()) {
      list.add(p);
    }
    return list;
  }

  Stream<SourceVariant> streamVariants() async* {
    final file = File(config.variantsPath);
    final lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      yield SourceVariant(raw: jsonDecode(line) as Map<String, dynamic>);
    }
  }

  Future<List<SourceVariant>> loadAllVariants() async {
    final list = <SourceVariant>[];
    await for (final v in streamVariants()) {
      list.add(v);
    }
    return list;
  }

  Future<Map<String, SourceImageMapEntry>> loadImageMap() async {
    final file = File(config.imageMapPath);
    if (!file.existsSync()) return {};
    final list = jsonDecode(await file.readAsString()) as List;
    final map = <String, SourceImageMapEntry>{};
    for (final entry in list) {
      final e = SourceImageMapEntry.fromJson(
        Map<String, dynamic>.from(entry as Map),
      );
      if (e.localFile.isNotEmpty) {
        map[e.localFile] = e;
      }
    }
    return map;
  }
}
