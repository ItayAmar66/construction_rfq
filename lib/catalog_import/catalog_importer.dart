import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_meta.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import '../repositories/catalog/catalog_firestore_converter.dart';
import '../utils/catalog_constants.dart';
import 'demo_slice_selector.dart';
import 'full_catalog_builder.dart';
import 'import_checkpoint.dart';
import 'import_config.dart';

/// Writes catalog documents to Firestore or dry-run export.
class CatalogImporter {
  CatalogImporter({
    required this.config,
    FirebaseFirestore? firestore,
  }) : _db = firestore;

  final CatalogImportConfig config;
  final FirebaseFirestore? _db;

  Future<CatalogImportResult> runDemoSlice(DemoSliceResult slice) async {
    config.log(
      'Import demo slice: ${slice.categories.length} categories, '
      '${slice.products.length} products, ${slice.variants.length} variants',
    );

    if (config.dryRun) {
      return _dryRunExportSlice(slice, subdir: 'dry_run');
    }

    final db = _requireDb();
    return _writePayload(
      categories: slice.categories,
      products: slice.products,
      variants: slice.variants,
      isDemoSlice: true,
      db: db,
    );
  }

  Future<CatalogImportResult> runFullDryRun({
    required FullCatalogPayload payload,
    required CatalogValidationReportStats stats,
  }) async {
    final categories = payload.categories.length;
    final products = payload.products.length;
    final variants = payload.variants.length;
    final totalWrites = payload.totalFirestoreWrites;
    final batchSize = config.batchSize;
    final batches = _estimatedBatches(
      [categories, products, variants, 1],
      batchSize,
    );

    final outDir = Directory(
      '${config.outputDir ?? 'tools/catalog_import/out'}/full_dry_run',
    );
    await outDir.create(recursive: true);

    final summary = {
      'dryRun': true,
      'importVersion': config.importVersion,
      'categoriesPlanned': categories,
      'productsPlanned': products,
      'variantsPlanned': variants,
      'imagesMapped': stats.imageMapCount,
      'missingImages': stats.missingImagesOnDisk,
      'estimatedFirestoreWrites': totalWrites,
      'estimatedBatches': batches,
      'batchSize': batchSize,
      'warnings': stats.warnings,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final path = '${outDir.path}/summary.json';
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    config.log('Full dry-run summary → $path');

    return CatalogImportResult(
      dryRun: true,
      categoriesWritten: categories,
      productsWritten: products,
      variantsWritten: variants,
      outputPath: outDir.path,
    );
  }

  Future<CatalogImportResult> runFullImport(FullCatalogPayload payload) async {
    config.log(
      'Full import: ${payload.categories.length} categories, '
      '${payload.products.length} products, ${payload.variants.length} variants',
    );

    if (config.dryRun) {
      throw StateError('runFullImport called while dryRun=true');
    }

    final db = _requireDb();
    return _writePayload(
      categories: payload.categories,
      products: payload.products,
      variants: payload.variants,
      isDemoSlice: false,
      db: db,
    );
  }

  Future<CatalogImportResult> _writePayload({
    required List<CatalogCategory> categories,
    required List<CatalogProduct> products,
    required List<CatalogVariant> variants,
    required bool isDemoSlice,
    required FirebaseFirestore db,
  }) async {
    ImportCheckpoint? checkpoint;
    if (config.resume) {
      checkpoint = await ImportCheckpoint.load(config.checkpointPath);
      if (checkpoint != null &&
          checkpoint.importVersion != config.importVersion) {
        config.log(
          'Checkpoint version mismatch (${checkpoint.importVersion} vs '
          '${config.importVersion}); starting fresh.',
        );
        checkpoint = null;
      } else if (checkpoint != null) {
        config.log(
          'Resuming from phase ${checkpoint.phase} offset ${checkpoint.skipped}',
        );
      }
    } else {
      await ImportCheckpoint.clear(config.checkpointPath);
    }

    var categoriesWritten = 0;
    var productsWritten = 0;
    var variantsWritten = 0;

    final startPhase = checkpoint?.phase ?? 'categories';
    final phases = ImportCheckpoint.phases;

    for (final phase in phases) {
      if (phases.indexOf(phase) < phases.indexOf(startPhase)) continue;
      if (phase == 'meta') continue;

      final skip = phase == startPhase ? (checkpoint?.skipped ?? 0) : 0;
      switch (phase) {
        case 'categories':
          categoriesWritten = await _writeBatches(
            db,
            CatalogConstants.categoriesCollection,
            categories.map(
              (c) => MapEntry(c.id, CatalogFirestoreConverter.categoryToMap(c)),
            ),
            phase: phase,
            skip: skip,
            total: categories.length,
          );
        case 'products':
          productsWritten = await _writeBatches(
            db,
            CatalogConstants.productsCollection,
            products.map(
              (p) => MapEntry(
                p.id,
                CatalogFirestoreConverter.productToMap(p, forImport: true),
              ),
            ),
            phase: phase,
            skip: skip,
            total: products.length,
          );
        case 'variants':
          variantsWritten = await _writeBatches(
            db,
            CatalogConstants.variantsCollection,
            variants.map(
              (v) => MapEntry(v.id, CatalogFirestoreConverter.variantToMap(v)),
            ),
            phase: phase,
            skip: skip,
            total: variants.length,
          );
      }
      await _saveCheckpoint(phase, skip: 0, total: 0, done: true);
    }

    final meta = CatalogMeta(
      version: isDemoSlice
          ? 'demo-${config.importVersion}'
          : config.importVersion,
      productCount: productsWritten,
      variantCount: variantsWritten,
      categoryCount: categoriesWritten,
      importedAt: DateTime.now().toUtc(),
      isDemoSlice: isDemoSlice,
    );

    await db
        .collection(CatalogConstants.metaCollection)
        .doc(CatalogConstants.metaCurrentDocId)
        .set(CatalogFirestoreConverter.metaToMap(meta));

    await ImportCheckpoint.clear(config.checkpointPath);
    config.log('catalogMeta/current written (import complete).');

    return CatalogImportResult(
      dryRun: false,
      categoriesWritten: categoriesWritten,
      productsWritten: productsWritten,
      variantsWritten: variantsWritten,
      outputPath: null,
    );
  }

  Future<void> _saveCheckpoint(
    String phase, {
    required int skip,
    required int total,
    bool done = false,
  }) async {
    if (!config.writeToFirestore || config.dryRun) return;
    if (done) {
      final nextIndex = ImportCheckpoint.phases.indexOf(phase) + 1;
      if (nextIndex >= ImportCheckpoint.phases.length) return;
      await ImportCheckpoint.save(
        config.checkpointPath,
        ImportCheckpoint(
          importVersion: config.importVersion,
          phase: ImportCheckpoint.phases[nextIndex],
          skipped: 0,
          total: 0,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return;
    }
    await ImportCheckpoint.save(
      config.checkpointPath,
      ImportCheckpoint(
        importVersion: config.importVersion,
        phase: phase,
        skipped: skip,
        total: total,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<CatalogImportResult> _dryRunExportSlice(
    DemoSliceResult slice, {
    required String subdir,
  }) async {
    final outDir = Directory(config.outputDir ?? 'tools/catalog_import/out');
    final dryDir = Directory('${outDir.path}/$subdir');
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
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  Future<int> _writeBatches(
    FirebaseFirestore db,
    String collection,
    Iterable<MapEntry<String, Map<String, dynamic>>> docs, {
    required String phase,
    int skip = 0,
    required int total,
  }) async {
    final list = docs.toList();
    var written = skip;
    final batchSize = config.batchSize;

    for (var i = skip; i < list.length; i += batchSize) {
      final end = min(i + batchSize, list.length);
      final chunk = list.sublist(i, end);
      final batch = db.batch();
      for (final entry in chunk) {
        batch.set(
          db.collection(collection).doc(entry.key),
          entry.value,
        );
      }
      await batch.commit();
      written += chunk.length;

      if (written % config.logProgressEvery == 0 || end == list.length) {
        config.log('  $collection: $written / ${list.length}');
      }

      await _saveCheckpoint(phase, skip: written, total: list.length);
    }

    return written;
  }

  FirebaseFirestore _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('Firestore instance required for write import');
    }
    return db;
  }

  static int _estimatedBatches(List<int> counts, int batchSize) {
    var batches = 0;
    for (final c in counts) {
      batches += (c / batchSize).ceil();
    }
    return batches;
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

/// Stats passed into full dry-run summary.
class CatalogValidationReportStats {
  const CatalogValidationReportStats({
    required this.imageMapCount,
    required this.missingImagesOnDisk,
    required this.warnings,
  });

  final int imageMapCount;
  final int missingImagesOnDisk;
  final List<String> warnings;
}
