import 'dart:io';

import 'catalog_etl.dart';
import 'dataset_loader.dart';
import 'demo_slice_selector.dart';
import 'import_config.dart';
/// Integrity checks on normalized catalog dataset (and demo slice).
class CatalogValidator {
  CatalogValidator({
    required this.config,
    required this.loader,
  });

  final CatalogImportConfig config;
  final CatalogDatasetLoader loader;

  Future<CatalogValidationReport> validateFull() async {
    config.log('Validating full dataset at ${config.dataRoot}...');
    final forest = await loader.loadCategoryForest();
    final flat = loader.flattenCategories(forest);
    final categoryIndex = CatalogEtl.buildCategoryIndex(forest);
    final imageMap = await loader.loadImageMap();

    final categoryIds = categoryIndex.keys.toSet();
    final errors = <String>[];
    final warnings = <String>[];

    for (final node in flat) {
      if (node.parentId != null && !categoryIds.contains(node.parentId)) {
        errors.add('Category ${node.id} has missing parent ${node.parentId}');
      }
    }

    var productCount = 0;
    var productsWithoutCategory = 0;
    var missingPrimaryImage = 0;
    final productIds = <String>{};

    await for (final sp in loader.streamProducts()) {
      productCount++;
      productIds.add(sp.id.toString());
      if (sp.categoryIds.isEmpty) {
        productsWithoutCategory++;
      }
      for (final cid in sp.categoryIds) {
        if (!categoryIds.contains(cid)) {
          errors.add('Product ${sp.id} references missing category $cid');
        }
      }
      if (sp.primaryImage != null && sp.primaryImage!.isNotEmpty) {
        final rel = sp.primaryImage!;
        final candidates = [
          File(rel),
          File('${config.dataRoot}/$rel'),
          File('${config.imagesDir}/${_basename(rel)}'),
        ];
        final existsOnDisk = candidates.any((f) => f.existsSync());
        if (!existsOnDisk && !imageMap.containsKey(rel)) {
          missingPrimaryImage++;
        }
      }
    }

    var variantCount = 0;
    var orphanVariants = 0;
    await for (final sv in loader.streamVariants()) {
      variantCount++;
      var linked = false;
      for (final pid in sv.productIds) {
        if (productIds.contains(pid.toString())) {
          linked = true;
          break;
        }
      }
      if (!linked) orphanVariants++;
    }

    if (productsWithoutCategory > 0) {
      warnings.add('$productsWithoutCategory products have no categoryIds');
    }
    if (missingPrimaryImage > 0) {
      warnings.add('$missingPrimaryImage products reference images not on disk');
    }
    if (orphanVariants > 0) {
      warnings.add('$orphanVariants variants have no linked product in products.jsonl');
    }

    return CatalogValidationReport(
      categoryCount: categoryIndex.length,
      productCount: productCount,
      variantCount: variantCount,
      imageMapCount: imageMap.length,
      errors: errors,
      warnings: warnings,
      passed: errors.isEmpty,
    );
  }

  Future<CatalogValidationReport> validateDemoSlice(
    DemoSliceResult slice,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];

    final categoryIds = slice.categories.map((c) => c.id).toSet();
    final productIds = slice.products.map((p) => p.id).toSet();

    for (final p in slice.products) {
      if (p.categoryIds.isEmpty) {
        errors.add('Demo product ${p.id} has no categories');
      }
      for (final cid in p.categoryIds) {
        if (!categoryIds.contains(cid)) {
          errors.add('Demo product ${p.id} missing category $cid in slice');
        }
      }
      if (p.primaryCategoryId.isEmpty) {
        warnings.add('Demo product ${p.id} has empty primaryCategoryId');
      }
    }

    for (final v in slice.variants) {
      if (!productIds.contains(v.productId)) {
        errors.add('Demo variant ${v.id} orphan productId ${v.productId}');
      }
      if (v.image.hasLocalPath) {
        final path = v.image.localPath!;
        if (!File(path).existsSync() &&
            !File('${config.dataRoot}/$path').existsSync()) {
          warnings.add('Demo variant ${v.id} image missing: $path');
        }
      }
    }

    for (final c in slice.categories) {
      if (c.parentId != null &&
          c.parentId!.isNotEmpty &&
          !categoryIds.contains(c.parentId)) {
        final inForest = await _parentExistsInFullDataset(c.parentId!);
        if (!inForest) {
          warnings.add(
            'Demo category ${c.id} parent ${c.parentId} not in demo slice',
          );
        }
      }
    }

    return CatalogValidationReport(
      categoryCount: slice.categories.length,
      productCount: slice.products.length,
      variantCount: slice.variants.length,
      imageMapCount: 0,
      errors: errors,
      warnings: warnings,
      passed: errors.isEmpty,
    );
  }

  Future<bool> _parentExistsInFullDataset(String parentId) async {
    final forest = await loader.loadCategoryForest();
    final flat = loader.flattenCategories(forest);
    return flat.any((n) => n.id.toString() == parentId);
  }

  String _basename(String path) {
    final parts = path.split('/');
    return parts.isEmpty ? path : parts.last;
  }
}

class CatalogValidationReport {
  const CatalogValidationReport({
    required this.categoryCount,
    required this.productCount,
    required this.variantCount,
    required this.imageMapCount,
    required this.errors,
    required this.warnings,
    required this.passed,
  });

  final int categoryCount;
  final int productCount;
  final int variantCount;
  final int imageMapCount;
  final List<String> errors;
  final List<String> warnings;
  final bool passed;

  @override
  String toString() {
    final buf = StringBuffer()
      ..writeln('Catalog validation: ${passed ? 'PASS' : 'FAIL'}')
      ..writeln('  categories: $categoryCount')
      ..writeln('  products:   $productCount')
      ..writeln('  variants:   $variantCount')
      ..writeln('  image map:  $imageMapCount');
    if (warnings.isNotEmpty) {
      buf.writeln('Warnings (${warnings.length}):');
      for (final w in warnings.take(20)) {
        buf.writeln('  - $w');
      }
      if (warnings.length > 20) {
        buf.writeln('  ... and ${warnings.length - 20} more');
      }
    }
    if (errors.isNotEmpty) {
      buf.writeln('Errors (${errors.length}):');
      for (final e in errors.take(30)) {
        buf.writeln('  - $e');
      }
    }
    return buf.toString();
  }
}
