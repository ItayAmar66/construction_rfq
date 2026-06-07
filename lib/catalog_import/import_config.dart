import 'dart:convert';
import 'dart:io';

import 'firestore_batch_retry.dart';

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
    this.verifyProduction = false,
    this.writeToFirestore = false,
    this.requireEmulator = false,
    this.productionMode = false,
    this.resume = false,
    this.batchDelayMsOverride,
    this.readPageDelayMsOverride,
    this.listPageSizeOverride,
    this.countPageSizeOverride,
    this.maxRetryAttempts = CatalogImportRetryDefaults.maxAttempts,
    this.retryBaseDelayMs = CatalogImportRetryDefaults.baseDelayMs,
    this.retryMaxDelayMs = CatalogImportRetryDefaults.maxDelayMs,
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
    this.firestoreTarget,
    this.firebaseProjectId,
    this.confirmProductionImport,
    this.collections = const CatalogImportCollections(),
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
  final bool verifyProduction;
  final bool writeToFirestore;
  final bool requireEmulator;
  final bool productionMode;
  final bool resume;
  final int? batchDelayMsOverride;
  final int? readPageDelayMsOverride;
  final int? listPageSizeOverride;
  final int? countPageSizeOverride;
  final int maxRetryAttempts;
  final int retryBaseDelayMs;
  final int retryMaxDelayMs;
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
  final String? firestoreTarget;
  final String? firebaseProjectId;
  final String? confirmProductionImport;
  final CatalogImportCollections collections;
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

  bool get isProductionTarget =>
      productionMode || firestoreTarget == 'production';

  bool get isVerifyMode => verifyEmulator || verifyProduction;

  String get verificationOutputSubdir => verifyProduction
      ? 'production_verification'
      : 'emulator_verification';

  /// Delay between Firestore batches (production throttling).
  int get batchDelayMs {
    if (batchDelayMsOverride != null) return batchDelayMsOverride!;
    if (isProductionTarget) {
      return CatalogImportRetryDefaults.productionBatchDelayMs;
    }
    return 0;
  }

  int get readPageDelayMs {
    if (readPageDelayMsOverride != null) return readPageDelayMsOverride!;
    if (isProductionTarget) {
      return CatalogImportRetryDefaults.productionReadPageDelayMs;
    }
    return 0;
  }

  int get listPageSize {
    if (listPageSizeOverride != null) return listPageSizeOverride!;
    if (isProductionTarget) {
      return CatalogImportRetryDefaults.productionListPageSize;
    }
    return 500;
  }

  int get countPageSize {
    if (countPageSizeOverride != null) return countPageSizeOverride!;
    if (isProductionTarget) {
      return CatalogImportRetryDefaults.productionCountPageSize;
    }
    return 1000;
  }

  int get maxRetries => maxRetryAttempts;
  int get initialBackoffMs => retryBaseDelayMs;
  int get maxBackoffMs => retryMaxDelayMs;

  FirestoreBatchRetryPolicy get firestoreRetryPolicy {
    if (!isProductionTarget) {
      return FirestoreBatchRetryPolicy.none();
    }
    return FirestoreBatchRetryPolicy.production(
      maxAttempts: maxRetryAttempts,
      baseDelayMs: retryBaseDelayMs,
      maxDelayMs: retryMaxDelayMs,
      log: log,
    );
  }

  /// Alias for [firestoreRetryPolicy].
  FirestoreBatchRetryPolicy get writeRetryPolicy => firestoreRetryPolicy;

  /// Full catalog write is allowed when emulator or production safety checks pass.
  bool get allowsFullFirestoreWrite {
    if (!writeToFirestore || !importFull) return false;
    if (isProductionTarget) {
      return CatalogImportSafety.refuseProductionWriteReason(this) == null;
    }
    return requireEmulator && CatalogImportSafety.isEmulatorHostConfigured;
  }

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
    var verifyProduction = false;
    var write = false;
    var requireEmulator = false;
    var productionMode = false;
    var resume = false;
    String? configFilePath;
    String? firebaseProjectId;
    String? confirmProductionImport;
    var explicitWrite = false;
    var explicitImportFull = false;
    var explicitImportDemo = false;

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
          explicitImportDemo = true;
          importDemo = true;
          dryRun = false;
        case '--import-full':
          explicitImportFull = true;
          importFull = true;
          dryRun = false;
        case '--write':
          explicitWrite = true;
          write = true;
          dryRun = false;
        case '--emulator':
          requireEmulator = true;
        case '--production':
          productionMode = true;
        case '--resume':
          resume = true;
        case '--rollback-catalog':
          rollbackCatalog = true;
        case '--verify-emulator':
          verifyEmulator = true;
        case '--verify-production':
          verifyProduction = true;
        default:
          if (arg.startsWith('--config=')) {
            configFilePath = arg.substring('--config='.length);
          } else if (arg.startsWith('--project=')) {
            firebaseProjectId = arg.substring('--project='.length);
          } else if (arg.startsWith('--confirm-production-import=')) {
            confirmProductionImport =
                arg.substring('--confirm-production-import='.length);
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
    String? firestoreTarget;
    var collections = const CatalogImportCollections();
    int? batchDelayMsOverride;
    int? readPageDelayMsOverride;
    int? listPageSizeOverride;
    int? countPageSizeOverride;
    var maxRetryAttempts = CatalogImportRetryDefaults.maxAttempts;
    var retryBaseDelayMs = CatalogImportRetryDefaults.baseDelayMs;
    var retryMaxDelayMs = CatalogImportRetryDefaults.maxDelayMs;

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
      firestoreTarget = loaded['firestoreTarget'] as String?;
      firebaseProjectId =
          loaded['firebaseProjectId'] as String? ?? firebaseProjectId;
      if (firestoreTarget == 'production') {
        productionMode = true;
      }
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
      batchDelayMsOverride = loaded['batchDelayMs'] as int? ?? batchDelayMsOverride;
      readPageDelayMsOverride =
          loaded['readPageDelayMs'] as int? ?? readPageDelayMsOverride;
      listPageSizeOverride =
          loaded['listPageSize'] as int? ?? listPageSizeOverride;
      countPageSizeOverride =
          loaded['countPageSize'] as int? ?? countPageSizeOverride;
      maxRetryAttempts = loaded['maxRetries'] as int? ??
          loaded['maxRetryAttempts'] as int? ??
          maxRetryAttempts;
      retryBaseDelayMs = loaded['initialBackoffMs'] as int? ??
          loaded['retryBaseDelayMs'] as int? ??
          retryBaseDelayMs;
      retryMaxDelayMs = loaded['maxBackoffMs'] as int? ??
          loaded['retryMaxDelayMs'] as int? ??
          retryMaxDelayMs;
      final throttle = loaded['productionThrottling'] as Map<String, dynamic>?;
      if (throttle != null) {
        batchDelayMsOverride =
            throttle['batchDelayMs'] as int? ?? batchDelayMsOverride;
        readPageDelayMsOverride =
            throttle['readPageDelayMs'] as int? ?? readPageDelayMsOverride;
        listPageSizeOverride =
            throttle['listPageSize'] as int? ?? listPageSizeOverride;
        countPageSizeOverride =
            throttle['countPageSize'] as int? ?? countPageSizeOverride;
        maxRetryAttempts = throttle['maxRetries'] as int? ??
            throttle['maxRetryAttempts'] as int? ??
            maxRetryAttempts;
        retryBaseDelayMs = throttle['initialBackoffMs'] as int? ??
            throttle['retryBaseDelayMs'] as int? ??
            retryBaseDelayMs;
        retryMaxDelayMs = throttle['maxBackoffMs'] as int? ??
            throttle['retryMaxDelayMs'] as int? ??
            retryMaxDelayMs;
      }
      final rawCollections = loaded['collections'];
      if (rawCollections is Map<String, dynamic>) {
        collections = CatalogImportCollections.fromJson(rawCollections);
      }
    }

    // Verify modes are read-only; config files may set write/import for resume runs.
    if (verifyProduction || verifyEmulator) {
      if (!explicitWrite && !explicitImportFull && !explicitImportDemo) {
        write = false;
        dryRun = true;
        importFull = false;
        importDemo = false;
        resume = false;
        rollbackCatalog = false;
      }
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
      verifyProduction: verifyProduction,
      writeToFirestore: write,
      requireEmulator: requireEmulator,
      productionMode: productionMode,
      resume: resume,
      batchDelayMsOverride: batchDelayMsOverride,
      readPageDelayMsOverride: readPageDelayMsOverride,
      listPageSizeOverride: listPageSizeOverride,
      countPageSizeOverride: countPageSizeOverride,
      maxRetryAttempts: maxRetryAttempts,
      retryBaseDelayMs: retryBaseDelayMs,
      retryMaxDelayMs: retryMaxDelayMs,
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
      firestoreTarget: firestoreTarget,
      firebaseProjectId: firebaseProjectId,
      confirmProductionImport: confirmProductionImport,
      collections: collections,
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

class CatalogImportCollections {
  const CatalogImportCollections({
    this.categories = 'catalogCategories',
    this.products = 'catalogProducts',
    this.variants = 'catalogVariants',
    this.meta = 'catalogMeta',
  });

  factory CatalogImportCollections.fromJson(Map<String, dynamic> json) {
    return CatalogImportCollections(
      categories: json['categories'] as String? ?? 'catalogCategories',
      products: json['products'] as String? ?? 'catalogProducts',
      variants: json['variants'] as String? ?? 'catalogVariants',
      meta: json['meta'] as String? ?? 'catalogMeta',
    );
  }

  final String categories;
  final String products;
  final String variants;
  final String meta;
}

abstract final class CatalogImportDefaults {
  static const int demoCategoryLimit = 20;
  static const int demoProductLimit = 100;
  static const int demoVariantLimit = 300;
  static const int batchSize = 450;
  static const int logProgressEvery = 1000;
  static const String importVersion = 'catalog-full-v1';
}

abstract final class CatalogImportProduction {
  static const requiredProjectId = 'construction-rfq-itay-20-2eee0';
}

/// Guards against accidental production writes.
abstract final class CatalogImportSafety {
  static bool get isEmulatorHostConfigured {
    final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    return host != null && host.trim().isNotEmpty;
  }

  static String? refuseFullWriteReason(CatalogImportConfig config) {
    if (!config.writeToFirestore || !config.importFull) return null;

    if (config.isProductionTarget) {
      return refuseProductionWriteReason(config);
    }

    if (!config.requireEmulator) {
      return 'Full import write requires --emulator or explicit --production with confirmation.';
    }
    if (!isEmulatorHostConfigured) {
      return 'Full import write requires FIRESTORE_EMULATOR_HOST (e.g. 127.0.0.1:8080).';
    }
    return null;
  }

  static String? refuseProductionWriteReason(CatalogImportConfig config) {
    if (!config.isProductionTarget || !config.writeToFirestore) return null;
    if (!config.importFull) {
      return 'Production import requires --import-full.';
    }
    if (!config.productionMode) {
      return 'Production import requires --production flag.';
    }
    if (config.requireEmulator) {
      return 'Production import cannot combine --emulator with --production.';
    }
    if (config.firebaseProjectId == null ||
        config.firebaseProjectId!.trim().isEmpty) {
      return 'Production import requires --project=${CatalogImportProduction.requiredProjectId}.';
    }
    if (config.firebaseProjectId != CatalogImportProduction.requiredProjectId) {
      return 'Production import project mismatch: expected '
          '${CatalogImportProduction.requiredProjectId}, got ${config.firebaseProjectId}.';
    }
    if (config.confirmProductionImport !=
        CatalogImportProduction.requiredProjectId) {
      return 'Production import requires '
          '--confirm-production-import=${CatalogImportProduction.requiredProjectId}.';
    }
    return null;
  }

  static String? refuseRollbackReason(CatalogImportConfig config) {
    if (!config.rollbackCatalog) return null;
    if (config.isProductionTarget) {
      return 'Production rollback is not supported; use emulator only.';
    }
    if (!config.requireEmulator) {
      return 'Rollback requires --emulator flag.';
    }
    if (!isEmulatorHostConfigured) {
      return 'Rollback requires FIRESTORE_EMULATOR_HOST.';
    }
    return null;
  }

  static String? refuseVerifyWriteConflict(CatalogImportConfig config) {
    if (!config.isVerifyMode) return null;
    if (config.writeToFirestore) {
      return 'Verify is read-only; do not combine verify with --write or config write:true.';
    }
    if (config.importFull || config.importDemo) {
      return 'Verify is read-only; do not combine verify with --import-full/--import-demo.';
    }
    return null;
  }

  static String? refuseVerifyReason(CatalogImportConfig config) {
    if (config.verifyProduction) {
      if (!config.productionMode) {
        return 'Production verify requires --production flag.';
      }
      if (config.firebaseProjectId == null ||
          config.firebaseProjectId!.trim().isEmpty) {
        return 'Production verify requires --project=${CatalogImportProduction.requiredProjectId}.';
      }
      if (config.firebaseProjectId != CatalogImportProduction.requiredProjectId) {
        return 'Production verify project mismatch: expected '
            '${CatalogImportProduction.requiredProjectId}, got ${config.firebaseProjectId}.';
      }
      return null;
    }

    if (!config.verifyEmulator) return null;
    if (!isEmulatorHostConfigured) {
      return 'Verification requires FIRESTORE_EMULATOR_HOST.';
    }
    return null;
  }

  static String? refuseProductionDryRunReason(CatalogImportConfig config) {
    if (!config.isProductionTarget || config.writeToFirestore) return null;
    if (!config.productionMode) {
      return 'Production dry-run requires --production flag.';
    }
    if (config.firebaseProjectId == null ||
        config.firebaseProjectId!.trim().isEmpty) {
      return 'Production dry-run requires --project=${CatalogImportProduction.requiredProjectId}.';
    }
    if (config.firebaseProjectId != CatalogImportProduction.requiredProjectId) {
      return 'Production dry-run project mismatch: expected '
          '${CatalogImportProduction.requiredProjectId}, got ${config.firebaseProjectId}.';
    }
    return null;
  }
}
