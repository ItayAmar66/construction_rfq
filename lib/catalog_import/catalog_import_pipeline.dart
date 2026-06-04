import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalog_emulator_verifier.dart';
import 'catalog_etl.dart';
import 'catalog_importer.dart';
import 'catalog_rollback.dart';
import 'catalog_validator.dart';
import 'dataset_loader.dart';
import 'demo_slice_selector.dart';
import 'full_catalog_builder.dart';
import 'import_config.dart';

/// Orchestrates validate → dry-run / import / rollback / verification.
class CatalogImportPipeline {
  CatalogImportPipeline(
    this.config, {
    FirebaseFirestore? firestore,
  })  : loader = CatalogDatasetLoader(config),
        validator = CatalogValidator(config: config, loader: CatalogDatasetLoader(config)),
        _firestore = firestore;

  final CatalogImportConfig config;
  final CatalogDatasetLoader loader;
  final CatalogValidator validator;
  final FirebaseFirestore? _firestore;

  Future<CatalogPipelineResult> run() async {
    if (!config.pathsExist) {
      throw StateError(
        'Catalog data not found under ${config.dataRoot}. '
        'Set CATALOG_DATA_ROOT or check tools/catalog_import/config.example.json',
      );
    }

    config.log('=== Catalog import pipeline ===');
    config.log('dataRoot: ${config.dataRoot}');
    config.log(
      'mode: validateOnly=${config.validateOnly} fullDryRun=${config.fullDryRun} '
      'importFull=${config.importFull} importDemo=${config.importDemo} '
      'rollback=${config.rollbackCatalog} verify=${config.verifyEmulator} '
      'dryRun=${config.dryRun} write=${config.writeToFirestore} resume=${config.resume}',
    );

    if (config.rollbackCatalog) {
      return _runRollback();
    }

    if (config.verifyEmulator) {
      return _runVerify();
    }

    final fullReport = await validator.validateFull();
    config.log(fullReport.toString());

    if (config.validateOnly && !config.fullDryRun && !config.importFull) {
      return CatalogPipelineResult(
        fullValidation: fullReport,
        sliceValidation: null,
        ok: fullReport.passed,
      );
    }

    if (config.fullDryRun || config.importFull) {
      return _runFullPath(fullReport);
    }

    return _runDemoPath(fullReport);
  }

  Future<CatalogPipelineResult> _runRollback() async {
    final db = _firestore;
    if (db == null) {
      throw StateError('Firestore required for rollback');
    }
    final result = await CatalogRollback(config: config, db: db).run();
    return CatalogPipelineResult(
      fullValidation: null,
      sliceValidation: null,
      rollback: result,
      ok: true,
    );
  }

  Future<CatalogPipelineResult> _runVerify() async {
    final db = _firestore;
    if (db == null) {
      throw StateError('Firestore required for verification');
    }
    final result = await CatalogEmulatorVerifier(config: config, db: db).run();
    return CatalogPipelineResult(
      fullValidation: null,
      sliceValidation: null,
      verification: result,
      ok: result.passed,
    );
  }

  Future<CatalogPipelineResult> _runFullPath(
    CatalogValidationReport fullReport,
  ) async {
    final forest = await loader.loadCategoryForest();
    final categoryIndex = CatalogEtl.buildCategoryIndex(forest);
    final imageMap = await loader.loadImageMap();
    final etl = CatalogEtl(categoryById: categoryIndex, imageMap: imageMap);
    final builder = FullCatalogBuilder(config: config, loader: loader, etl: etl);

    config.log('Building full catalog payload...');
    final payload = await builder.build();
    config.log(
      'Payload: ${payload.categories.length}c '
      '${payload.products.length}p ${payload.variants.length}v',
    );

    final importer = CatalogImporter(config: config, firestore: _firestore);
    CatalogImportResult? importResult;

    if (config.fullDryRun) {
      importResult = await importer.runFullDryRun(
        payload: payload,
        stats: CatalogValidationReportStats(
          imageMapCount: fullReport.imageMapCount,
          missingImagesOnDisk: fullReport.missingImagesOnDisk,
          warnings: fullReport.warnings,
        ),
      );
    } else if (!config.validateOnly) {
      importResult = await importer.runFullImport(payload);
    }

    return CatalogPipelineResult(
      fullValidation: fullReport,
      sliceValidation: null,
      fullPayload: payload,
      importResult: importResult,
      ok: fullReport.passed &&
          (config.validateOnly ||
              importResult != null &&
                  (config.fullDryRun ? importResult.dryRun : !importResult.dryRun)),
    );
  }

  Future<CatalogPipelineResult> _runDemoPath(
    CatalogValidationReport fullReport,
  ) async {
    final forest = await loader.loadCategoryForest();
    final categoryIndex = CatalogEtl.buildCategoryIndex(forest);
    final imageMap = await loader.loadImageMap();
    final etl = CatalogEtl(categoryById: categoryIndex, imageMap: imageMap);

    config.log('Building demo slice (limits: '
        '${config.categoryLimit}/${config.productLimit}/${config.variantLimit})...');

    final sourceProducts = await loader.loadAllProducts();
    final sourceVariants = await loader.loadAllVariants();

    final slice = DemoSliceSelector(
      categoryLimit: config.categoryLimit,
      productLimit: config.productLimit,
      variantLimit: config.variantLimit,
    ).select(
      allCategories: categoryIndex,
      sourceProducts: sourceProducts,
      sourceVariants: sourceVariants,
      etl: etl,
    );

    final sliceReport = await validator.validateDemoSlice(slice);
    config.log(sliceReport.toString());

    CatalogImportResult? importResult;
    if (!config.validateOnly) {
      final importer = CatalogImporter(config: config, firestore: _firestore);
      importResult = await importer.runDemoSlice(slice);
      config.log(
        importResult.dryRun
            ? 'Dry-run complete → ${importResult.outputPath}'
            : 'Demo import written: '
                '${importResult.categoriesWritten}c '
                '${importResult.productsWritten}p '
                '${importResult.variantsWritten}v',
      );
    }

    return CatalogPipelineResult(
      fullValidation: fullReport,
      sliceValidation: sliceReport,
      slice: slice,
      importResult: importResult,
      ok: fullReport.passed && sliceReport.passed,
    );
  }
}

class CatalogPipelineResult {
  const CatalogPipelineResult({
    this.fullValidation,
    this.sliceValidation,
    this.slice,
    this.fullPayload,
    this.importResult,
    this.rollback,
    this.verification,
    required this.ok,
  });

  final CatalogValidationReport? fullValidation;
  final CatalogValidationReport? sliceValidation;
  final DemoSliceResult? slice;
  final FullCatalogPayload? fullPayload;
  final CatalogImportResult? importResult;
  final CatalogRollbackResult? rollback;
  final CatalogVerificationResult? verification;
  final bool ok;
}
