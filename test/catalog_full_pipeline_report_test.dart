import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_pipeline.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prints validator + dry-run summary when local full dataset is present.
void main() {
  final dataRoot = Platform.environment['CATALOG_DATA_ROOT'] ??
      '/Users/itayamar/catalog-working';
  final hasDataset = File('$dataRoot/normalized/products.jsonl').existsSync();

  test(
    'Full dataset validator + demo dry-run report',
    () async {
      final messages = <String>[];
      final config = CatalogImportConfig(
        dataRoot: dataRoot,
        dryRun: true,
        validateOnly: false,
        outputDir: 'tools/catalog_import/out',
        categoryLimit: 20,
        productLimit: 100,
        variantLimit: 300,
        log: messages.add,
      );

      final result = await CatalogImportPipeline(config).run();

      // ignore: avoid_print
      print('\n--- Full dataset validation ---\n${result.fullValidation}');
      // ignore: avoid_print
      print('\n--- Demo slice validation ---\n${result.sliceValidation}');
      // ignore: avoid_print
      print(
        '\n--- Demo slice counts ---\n'
        'categories: ${result.slice.categories.length}\n'
        'products: ${result.slice.products.length}\n'
        'variants: ${result.slice.variants.length}',
      );
      if (result.importResult != null) {
        // ignore: avoid_print
        print('\n--- Dry-run export ---\n${result.importResult!.outputPath}');
      }

      expect(result.ok, isTrue);
      expect(result.slice.products.length, lessThanOrEqualTo(100));
      expect(result.slice.variants.length, lessThanOrEqualTo(300));
    },
    skip: !hasDataset,
  );
}
