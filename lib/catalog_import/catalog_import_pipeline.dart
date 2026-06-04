import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalog_etl.dart';
import 'catalog_importer.dart';
import 'catalog_validator.dart';
import 'dataset_loader.dart';
import 'demo_slice_selector.dart';
import 'import_config.dart';

/// Orchestrates validate → slice → dry-run / demo import.
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
    config.log('dryRun: ${config.dryRun} validateOnly: ${config.validateOnly} '
        'importDemo: ${config.importDemo} write: ${config.writeToFirestore}');

    final fullReport = await validator.validateFull();
    config.log(fullReport.toString());

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
    );
  }
}

class CatalogPipelineResult {
  const CatalogPipelineResult({
    required this.fullValidation,
    required this.sliceValidation,
    required this.slice,
    this.importResult,
  });

  final CatalogValidationReport fullValidation;
  final CatalogValidationReport sliceValidation;
  final DemoSliceResult slice;
  final CatalogImportResult? importResult;

  bool get ok => fullValidation.passed && sliceValidation.passed;
}
