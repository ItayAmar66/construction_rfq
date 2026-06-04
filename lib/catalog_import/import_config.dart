import 'dart:io';

/// Configuration for catalog import CLI (`lib/dev/catalog_import_main.dart`).
class CatalogImportConfig {
  CatalogImportConfig({
    required this.dataRoot,
    this.dryRun = true,
    this.validateOnly = false,
    this.importDemo = false,
    this.writeToFirestore = false,
    this.outputDir,
    this.categoryLimit = 20,
    this.productLimit = 100,
    this.variantLimit = 300,
    void Function(String message)? log,
  }) : log = log ?? _noopLog;

  static void _noopLog(String _) {}

  final String dataRoot;
  final bool dryRun;
  final bool validateOnly;
  final bool importDemo;
  final bool writeToFirestore;
  final String? outputDir;
  final int categoryLimit;
  final int productLimit;
  final int variantLimit;
  final void Function(String message) log;

  String get normalizedDir => '$dataRoot/normalized';
  String get assetsDir => '$dataRoot/assets';
  String get productsPath => '$normalizedDir/products.jsonl';
  String get variantsPath => '$normalizedDir/variants.jsonl';
  String get categoriesPath => '$normalizedDir/categories.flat.json';
  String get imageMapPath => '$assetsDir/image-map.json';
  String get imagesDir => '$assetsDir/images';

  static CatalogImportConfig fromArgs(
    List<String> args, {
    void Function(String message)? log,
  }) {
    final logger = log ?? (_) {};
    var dryRun = true;
    var validateOnly = false;
    var importDemo = false;
    var write = false;

    for (final arg in args) {
      switch (arg) {
        case '--validate':
          validateOnly = true;
          dryRun = true;
        case '--dry-run':
          dryRun = true;
        case '--import-demo':
          importDemo = true;
          dryRun = false;
        case '--write':
          write = true;
          dryRun = false;
      }
    }

    if (importDemo) {
      dryRun = !write;
    }

    final dataRoot = Platform.environment['CATALOG_DATA_ROOT'] ??
        '/Users/itayamar/catalog-working';

    final out = Platform.environment['CATALOG_IMPORT_OUTPUT'] ??
        'tools/catalog_import/out';

    return CatalogImportConfig(
      dataRoot: dataRoot,
      dryRun: dryRun,
      validateOnly: validateOnly,
      importDemo: importDemo,
      writeToFirestore: write,
      outputDir: out,
      log: logger,
    );
  }

  bool get pathsExist =>
      File(productsPath).existsSync() &&
      File(variantsPath).existsSync() &&
      File(categoriesPath).existsSync();
}
