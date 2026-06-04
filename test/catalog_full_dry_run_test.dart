import 'dart:convert';
import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_import_pipeline.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dataRoot = Platform.environment['CATALOG_DATA_ROOT'] ??
      '/Users/itayamar/catalog-working';
  final hasDataset = File('$dataRoot/normalized/products.jsonl').existsSync();

  test(
    'Full import dry-run writes summary.json',
    () async {
      final config = CatalogImportConfig(
        dataRoot: dataRoot,
        fullDryRun: true,
        dryRun: true,
        outputDir: 'tools/catalog_import/out',
        log: (_) {},
      );

      final result = await CatalogImportPipeline(config).run();
      expect(result.ok, isTrue);

      final summaryFile = File(config.fullDryRunSummaryPath);
      expect(summaryFile.existsSync(), isTrue);

      final summary =
          jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
      expect(summary['categoriesPlanned'], 418);
      expect(summary['productsPlanned'], 11149);
      expect(summary['variantsPlanned'], 31551);
      expect(summary['imagesMapped'], greaterThan(10000));
      expect(summary['estimatedFirestoreWrites'], greaterThan(43000));
      expect(summary['dryRun'], isTrue);

      final searchFields = summary['searchFields'] as Map<String, dynamic>?;
      expect(searchFields, isNotNull);
      expect(searchFields!['passed'], isTrue);
      expect(searchFields['variantsChecked'], 31551);
      expect(searchFields['variantsFailed'], 0);
    },
    skip: !hasDataset,
  );
}
