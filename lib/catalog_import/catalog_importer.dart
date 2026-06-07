import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_meta.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_variant.dart';
import '../repositories/catalog/catalog_firestore_converter.dart';
import '../utils/catalog_constants.dart';
import 'catalog_firestore_backend.dart';
import 'catalog_import_maps.dart';
import 'catalog_variant_search_field_verifier.dart';
import 'demo_slice_selector.dart';
import 'full_catalog_builder.dart';
import 'import_checkpoint.dart';
import 'import_config.dart';

/// Writes catalog documents to Firestore or dry-run export.
class CatalogImporter {
  CatalogImporter({
    required this.config,
    CatalogFirestoreBackend? backend,
  }) : _backend = backend;

  final CatalogImportConfig config;
  final CatalogFirestoreBackend? _backend;

  Future<CatalogImportResult> runDemoSlice(DemoSliceResult slice) async {
    config.log(
      'Import demo slice: ${slice.categories.length} categories, '
      '${slice.products.length} products, ${slice.variants.length} variants',
    );

    if (config.dryRun) {
      return _dryRunExportSlice(slice, subdir: 'dry_run');
    }

    return _writePayload(
      categories: slice.categories,
      products: slice.products,
      variants: slice.variants,
      isDemoSlice: true,
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

    final searchFieldReport =
        CatalogVariantSearchFieldVerifier.verifyAll(payload.variants);
    if (!searchFieldReport.passed) {
      config.log(
        'Search field verification FAIL: '
        '${searchFieldReport.variantsFailed}/${searchFieldReport.variantsChecked}',
      );
      for (final sample in searchFieldReport.sampleErrors.take(5)) {
        config.log('  $sample');
      }
    } else {
      config.log(
        'Search field verification PASS (${searchFieldReport.variantsChecked} variants)',
      );
    }

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
      'searchFields': searchFieldReport.toJson(),
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
      searchFieldsPassed: searchFieldReport.passed,
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

    return _writePayload(
      categories: payload.categories,
      products: payload.products,
      variants: payload.variants,
      isDemoSlice: false,
    );
  }

  Future<CatalogImportResult> _writePayload({
    required List<CatalogCategory> categories,
    required List<CatalogProduct> products,
    required List<CatalogVariant> variants,
    required bool isDemoSlice,
  }) async {
    final backend = _requireBackend();

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
          'Resuming from phase ${checkpoint.phase} offset ${checkpoint.skipped} '
          '(upsert idempotent — already-written docs will be updated)',
        );
      } else {
        config.log(
          'Resume requested but no checkpoint at ${config.checkpointPath}; '
          'starting full upsert from beginning.',
        );
      }
    } else {
      await ImportCheckpoint.clear(config.checkpointPath);
    }

    var categoriesWritten = 0;
    var productsWritten = 0;
    var variantsWritten = 0;

    final startPhase = checkpoint?.phase ?? 'categories';
    final startIndex = ImportCheckpoint.phases.indexOf(startPhase);
    final phases = ImportCheckpoint.phases;

    for (var phaseIndex = 0; phaseIndex < phases.length; phaseIndex++) {
      final phase = phases[phaseIndex];
      if (phase == 'meta') continue;

      if (phaseIndex < startIndex) {
        switch (phase) {
          case 'categories':
            categoriesWritten = categories.length;
          case 'products':
            productsWritten = products.length;
          case 'variants':
            variantsWritten = variants.length;
        }
        config.log(
          '  ${_collectionLabel(phase)}: skipped (checkpoint complete) '
          '${_countForPhase(phase, categories.length, products.length, variants.length)} / '
          '${_countForPhase(phase, categories.length, products.length, variants.length)}',
        );
        continue;
      }

      final skip = phase == startPhase ? (checkpoint?.skipped ?? 0) : 0;
      switch (phase) {
        case 'categories':
          categoriesWritten = await _writeBatches(
            backend,
            CatalogConstants.categoriesCollection,
            categories.map(
              (c) => MapEntry(c.id, CatalogImportMaps.category(c)),
            ),
            phase: phase,
            skip: skip,
            totalExpected: categories.length,
          );
        case 'products':
          productsWritten = await _writeBatches(
            backend,
            CatalogConstants.productsCollection,
            products.map((p) => MapEntry(p.id, CatalogImportMaps.product(p))),
            phase: phase,
            skip: skip,
            totalExpected: products.length,
          );
        case 'variants':
          variantsWritten = await _writeBatches(
            backend,
            CatalogConstants.variantsCollection,
            variants.map((v) => MapEntry(v.id, CatalogImportMaps.variant(v))),
            phase: phase,
            skip: skip,
            totalExpected: variants.length,
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

    await backend.setDocument(
      CatalogConstants.metaCollection,
      CatalogConstants.metaCurrentDocId,
      CatalogImportMaps.meta(meta),
    );

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
    CatalogFirestoreBackend backend,
    String collection,
    Iterable<MapEntry<String, Map<String, dynamic>>> docs, {
    required String phase,
    int skip = 0,
    required int totalExpected,
  }) async {
    final list = docs.toList();
    var written = skip;
    final batchSize = config.batchSize;
    final totalBatches = (list.length / batchSize).ceil().clamp(1, 1 << 30);

    config.log(
      'Writing ${_collectionLabel(phase)} ($collection): '
      '$totalExpected docs, batchSize=$batchSize, '
      'delay=${config.batchDelayMs}ms',
    );

    for (var i = skip; i < list.length; i += batchSize) {
      final end = min(i + batchSize, list.length);
      final chunk = list.sublist(i, end);
      final batchNumber = (i ~/ batchSize) + 1;

      await backend.batchSet(collection, chunk);
      written += chunk.length;

      config.log(
        '  ${_collectionLabel(phase)} batch $batchNumber/$totalBatches: '
        '$written / $totalExpected',
      );

      await _saveCheckpoint(phase, skip: written, total: list.length);

      if (end < list.length && config.batchDelayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: config.batchDelayMs));
      }
    }

    return written;
  }

  static String _collectionLabel(String phase) => switch (phase) {
        'categories' => 'catalogCategories',
        'products' => 'catalogProducts',
        'variants' => 'catalogVariants',
        _ => phase,
      };

  static int _countForPhase(
    String phase,
    int categories,
    int products,
    int variants,
  ) =>
      switch (phase) {
        'categories' => categories,
        'products' => products,
        'variants' => variants,
        _ => 0,
      };

  CatalogFirestoreBackend _requireBackend() {
    final backend = _backend;
    if (backend == null) {
      throw StateError('Firestore backend required for write import');
    }
    return backend;
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
    this.searchFieldsPassed = true,
  });

  final bool dryRun;
  final int categoriesWritten;
  final int productsWritten;
  final int variantsWritten;
  final String? outputPath;

  /// Full dry-run / import: all variants include search index fields.
  final bool searchFieldsPassed;
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
