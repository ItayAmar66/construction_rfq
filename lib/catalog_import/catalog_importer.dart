import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog/catalog_meta.dart';
import '../repositories/catalog/catalog_firestore_converter.dart';
import '../utils/catalog_constants.dart';
import 'demo_slice_selector.dart';
import 'import_config.dart';

/// Writes catalog documents to Firestore (demo slice only) or dry-run export.
class CatalogImporter {
  CatalogImporter({
    required this.config,
    FirebaseFirestore? firestore,
  }) : _db = firestore;

  final CatalogImportConfig config;
  final FirebaseFirestore? _db;

  static const int batchLimit = 450;

  Future<CatalogImportResult> runDemoSlice(DemoSliceResult slice) async {
    config.log(
      'Import demo slice: ${slice.categories.length} categories, '
      '${slice.products.length} products, ${slice.variants.length} variants',
    );

    if (config.dryRun) {
      return _dryRunExport(slice);
    }

    final db = _db;
    if (db == null) {
      throw StateError('Firestore instance required for write import');
    }

    var categoriesWritten = 0;
    var productsWritten = 0;
    var variantsWritten = 0;

    categoriesWritten += await _writeBatches(
      db,
      CatalogConstants.categoriesCollection,
      slice.categories.map((c) => MapEntry(c.id, CatalogFirestoreConverter.categoryToMap(c))),
    );

    productsWritten += await _writeBatches(
      db,
      CatalogConstants.productsCollection,
      slice.products.map(
        (p) => MapEntry(p.id, CatalogFirestoreConverter.productToMap(p, forImport: true)),
      ),
    );

    variantsWritten += await _writeBatches(
      db,
      CatalogConstants.variantsCollection,
      slice.variants.map((v) => MapEntry(v.id, CatalogFirestoreConverter.variantToMap(v))),
    );

    final meta = CatalogMeta(
      version: 'demo-${DateTime.now().toUtc().toIso8601String()}',
      productCount: productsWritten,
      variantCount: variantsWritten,
      categoryCount: categoriesWritten,
      importedAt: DateTime.now().toUtc(),
      isDemoSlice: true,
    );

    await db
        .collection(CatalogConstants.metaCollection)
        .doc(CatalogConstants.metaCurrentDocId)
        .set(CatalogFirestoreConverter.metaToMap(meta));

    return CatalogImportResult(
      dryRun: false,
      categoriesWritten: categoriesWritten,
      productsWritten: productsWritten,
      variantsWritten: variantsWritten,
      outputPath: null,
    );
  }

  Future<CatalogImportResult> _dryRunExport(DemoSliceResult slice) async {
    final outDir = Directory(config.outputDir ?? 'tools/catalog_import/out');
    final dryDir = Directory('${outDir.path}/dry_run');
    await dryDir.create(recursive: true);

    await _writeJson(
      '${dryDir.path}/catalogCategories.json',
      slice.categories
          .map((c) => {'id': c.id, ...CatalogFirestoreConverter.categoryToMap(c)})
          .toList(),
    );
    await _writeJson(
      '${dryDir.path}/catalogProducts.json',
      slice.products
          .map((p) => {'id': p.id, ...CatalogFirestoreConverter.productToMap(p)})
          .toList(),
    );
    await _writeJson(
      '${dryDir.path}/catalogVariants.json',
      slice.variants
          .map((v) => {'id': v.id, ...CatalogFirestoreConverter.variantToMap(v)})
          .toList(),
    );

    final summary = {
      'dryRun': true,
      'categories': slice.categories.length,
      'products': slice.products.length,
      'variants': slice.variants.length,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _writeJson('${dryDir.path}/summary.json', summary);

    config.log('Dry-run export written to ${dryDir.path}');

    return CatalogImportResult(
      dryRun: true,
      categoriesWritten: slice.categories.length,
      productsWritten: slice.products.length,
      variantsWritten: slice.variants.length,
      outputPath: dryDir.path,
    );
  }

  Future<void> _writeJson(String path, Object data) async {
    final file = File(path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  Future<int> _writeBatches(
    FirebaseFirestore db,
    String collection,
    Iterable<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    var written = 0;
    final list = docs.toList();
    for (var i = 0; i < list.length; i += batchLimit) {
      final chunk = list.sublist(
        i,
        i + batchLimit > list.length ? list.length : i + batchLimit,
      );
      final batch = db.batch();
      for (final entry in chunk) {
        batch.set(
          db.collection(collection).doc(entry.key),
          entry.value,
        );
      }
      await batch.commit();
      written += chunk.length;
      config.log('  $collection: $written / ${list.length}');
    }
    return written;
  }
}

class CatalogImportResult {
  const CatalogImportResult({
    required this.dryRun,
    required this.categoriesWritten,
    required this.productsWritten,
    required this.variantsWritten,
    this.outputPath,
  });

  final bool dryRun;
  final int categoriesWritten;
  final int productsWritten;
  final int variantsWritten;
  final String? outputPath;
}
