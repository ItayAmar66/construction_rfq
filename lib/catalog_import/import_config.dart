import 'dart:convert';
import 'dart:io';

/// Configuration for catalog import CLI (`tool/catalog_import_main.dart`).
class CatalogImportConfig {
  CatalogImportConfig({
    required this.dataRoot,
    this.sourceExportPath,
    this.dryRun = true,
    this.validateOnly = false,
    this.importDemo = false,
    this.importFull = false,
    this.fullDryRun = false,
    this.rollbackCatalog = false,
    this.verifyEmulator = false,
    this.writeToFirestore = false,
    this.requireEmulator = false,
    this.resume = false,
    this.outputDir,
    this.categoryLimit = CatalogImportDefaults.demoCategoryLimit,
    this.productLimit = CatalogImportDefaults.demoProductLimit,
    this.variantLimit = CatalogImportDefaults.demoVariantLimit,
    this.batchSize = CatalogImportDefaults.batchSize,
    this.logProgressEvery = CatalogImportDefaults.logProgressEvery,
    this.importVersion = CatalogImportDefaults.importVersion,
    this.maxCategoryRecords,
    this.maxProductRecords,
    this.maxVariantRecords,
    this.configFilePath,
    void Function(String message)? log,
  }) : log = log ?? _noopLog;

  static void _noopLog(String _) {}

  final String dataRoot;
  final String? sourceExportPath;
  final bool dryRun;
  final bool validateOnly;
  final bool importDemo;
  final bool importFull;
  final bool fullDryRun;
  final bool rollbackCatalog;
  final bool verifyEmulator;
  final bool writeToFirestore;
  final bool requireEmulator;
  final bool resume;
  final String? outputDir;
  final int categoryLimit;
  final int productLimit;
  final int variantLimit;
  final int batchSize;
  final int logProgressEvery;
  final String importVersion;
  final int? maxCategoryRecords;
  final int? maxProductRecords;
  final int? maxVariantRecords;
  final String? configFilePath;
  final void Function(String message) log;

  String get normalizedDir => '$dataRoot/normalized';
  String get assetsDir => '$dataRoot/assets';
  String get productsPath => '$normalizedDir/products.jsonl';
  String get variantsPath => '$normalizedDir/variants.jsonl';
  String get categoriesPath => '$normalizedDir/categories.flat.json';
  String get imageMapPath => '$assetsDir/image-map.json';
  String get imagesDir => '$assetsDir/images';

  String get checkpointPath =>
      '${outputDir ?? 'tools/catalog_import/out'}/import_checkpoint.json';

  String get fullDryRunSummaryPath =>
      '${outputDir ?? 'tools/catalog_import/out'}/full_dry_run/summary.json';

  bool get pathsExist =>
      File(productsPath).existsSync() &&
      File(variantsPath).existsSync() &&
      File(categoriesPath).existsSync();

  /// Full catalog write is allowed only when emulator is explicitly required and configured.
  bool get allowsFullFirestoreWrite =>
      writeToFirestore &&
      importFull &&
      requireEmulator &&
      CatalogImportSafety.isEmulatorHostConfigured;

  static CatalogImportConfig fromArgs(
    List<String> args, {
    void Function(String message)? log,
  }) {
    final logger = log ?? (_) {};
    var dryRun = true;
    var validateOnly = false;
    var importDemo = false;
    var importFull = false;
    var fullDryRun = false;
    var rollbackCatalog = false;
    var verifyEmulator = false;
    var write = false;
    var requireEmulator = false;
    var resume = false;
    String? configFilePath;

    for (final arg in args) {
      switch (arg) {
        case '--validate':
          validateOnly = true;
          dryRun = true;
        case '--dry-run':
          dryRun = true;
        case '--full-dry-run':
          fullDryRun = true;
          dryRun = true;
        case '--import-demo':
          importDemo = true;
          dryRun = false;
        case '--import-full':
          importFull = true;
          dryRun = false;
        case '--write':
          write = true;
          dryRun = false;
        case '--emulator':
          requireEmulator = true;
        case '--resume':
          resume = true;
        case '--rollback-catalog':
          rollbackCatalog = true;
        case '--verify-emulator':
          verifyEmulator = true;
        default:
          if (arg.startsWith('--config=')) {
            configFilePath = arg.substring('--config='.length);
          }
      }
    }

    if (importDemo || importFull) {
      dryRun = !write;
    }
    if (fullDryRun) {
      dryRun = true;
      write = false;
    }

    var dataRoot = Platform.environment['CATALOG_DATA_ROOT'] ??
        '/Users/itayamar/catalog-working';
    var out = Platform.environment['CATALOG_IMPORT_OUTPUT'] ??
        'tools/catalog_import/out';
    var batchSize = CatalogImportDefaults.batchSize;
    var logProgressEvery = CatalogImportDefaults.logProgressEvery;
    var importVersion = CatalogImportDefaults.importVersion;
    var categoryLimit = CatalogImportDefaults.demoCategoryLimit;
    var productLimit = CatalogImportDefaults.demoProductLimit;
    var variantLimit = CatalogImportDefaults.demoVariantLimit;
    String? sourceExportPath;
    int? maxCategoryRecords;
    int? maxProductRecords;
    int? maxVariantRecords;

    if (configFilePath != null) {
      final loaded = _loadJsonFile(configFilePath);
      dataRoot = loaded['dataRoot'] as String? ?? dataRoot;
      sourceExportPath = loaded['sourceExportPath'] as String?;
      out = loaded['outputDir'] as String? ?? out;
      batchSize = loaded['batchSize'] as int? ?? batchSize;
      logProgressEvery =
          loaded['logProgressEvery'] as int? ?? logProgressEvery;
      importVersion = loaded['importVersion'] as String? ?? importVersion;
      dryRun = loaded['dryRun'] as bool? ?? dryRun;
      write = loaded['write'] as bool? ?? write;
      resume = loaded['resume'] as bool? ?? resume;
      requireEmulator = loaded['requireEmulator'] as bool? ?? requireEmulator;
      maxCategoryRecords = loaded['maxCategoryRecords'] as int?;
      maxProductRecords = loaded['maxProductRecords'] as int?;
      maxVariantRecords = loaded['maxVariantRecords'] as int?;
      final demo = loaded['demoSlice'] as Map<String, dynamic>?;
      if (demo != null) {
        categoryLimit = demo['categoryLimit'] as int? ?? categoryLimit;
        productLimit = demo['productLimit'] as int? ?? productLimit;
        variantLimit = demo['variantLimit'] as int? ?? variantLimit;
      }
      if (loaded['fullDryRun'] == true) fullDryRun = true;
      if (loaded['importFull'] == true) importFull = true;
    }

    return CatalogImportConfig(
      dataRoot: dataRoot,
      sourceExportPath: sourceExportPath,
      dryRun: dryRun,
      validateOnly: validateOnly,
      importDemo: importDemo,
      importFull: importFull,
      fullDryRun: fullDryRun,
      rollbackCatalog: rollbackCatalog,
      verifyEmulator: verifyEmulator,
      writeToFirestore: write,
      requireEmulator: requireEmulator,
      resume: resume,
      outputDir: out,
      categoryLimit: categoryLimit,
      productLimit: productLimit,
      variantLimit: variantLimit,
      batchSize: batchSize,
      logProgressEvery: logProgressEvery,
      importVersion: importVersion,
      maxCategoryRecords: maxCategoryRecords,
      maxProductRecords: maxProductRecords,
      maxVariantRecords: maxVariantRecords,
      configFilePath: configFilePath,
      log: logger,
    );
  }

  static Map<String, dynamic> _loadJsonFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Config file not found: $path');
    }
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

abstract final class CatalogImportDefaults {
  static const int demoCategoryLimit = 20;
  static const int demoProductLimit = 100;
  static const int demoVariantLimit = 300;
  static const int batchSize = 450;
  static const int logProgressEvery = 1000;
  static const String importVersion = 'catalog-full-v1';
}

/// Guards against accidental production writes.
abstract final class CatalogImportSafety {
  static bool get isEmulatorHostConfigured {
    final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    return host != null && host.trim().isNotEmpty;
  }

  static String? refuseFullWriteReason(CatalogImportConfig config) {
    if (!config.writeToFirestore || !config.importFull) return null;
    if (!config.requireEmulator) {
      return 'Full import write requires --emulator flag.';
    }
    if (!isEmulatorHostConfigured) {
      return 'Full import write requires FIRESTORE_EMULATOR_HOST (e.g. 127.0.0.1:8080).';
    }
    return null;
  }

  static String? refuseRollbackReason(CatalogImportConfig config) {
    if (!config.rollbackCatalog) return null;
    if (!config.requireEmulator) {
      return 'Rollback requires --emulator flag.';
    }
    if (!isEmulatorHostConfigured) {
      return 'Rollback requires FIRESTORE_EMULATOR_HOST.';
    }
    return null;
  }

  static String? refuseVerifyReason(CatalogImportConfig config) {
    if (!config.verifyEmulator) return null;
    if (!isEmulatorHostConfigured) {
      return 'Verification requires FIRESTORE_EMULATOR_HOST.';
    }
    return null;
  }
}
