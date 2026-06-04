import 'dart:io';

import 'package:construction_rfq/catalog_import/catalog_etl.dart';
import 'package:construction_rfq/catalog_import/catalog_import_pipeline.dart';
import 'package:construction_rfq/catalog_import/catalog_text_utils.dart';
import 'package:construction_rfq/catalog_import/demo_slice_selector.dart';
import 'package:construction_rfq/catalog_import/dataset_loader.dart';
import 'package:construction_rfq/catalog_import/import_config.dart';
import 'package:construction_rfq/models/catalog/catalog_list_query.dart';
import 'package:construction_rfq/repositories/catalog/memory_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixtureRoot() {
  return '${Directory.current.path}/test/fixtures/catalog_mini';
}

void main() {
  test('CatalogTextUtils builds search tokens', () {
    final tokens = CatalogTextUtils.buildSearchTokens(
      name: 'מלט אפור',
      aka: ['פורטלנד'],
    );
    expect(tokens, isNotEmpty);
    expect(tokens.any((t) => t.contains('מלט')), isTrue);
  });

  test('ETL + demo slice + memory repository pagination', () async {
    final config = CatalogImportConfig(
      dataRoot: _fixtureRoot(),
      dryRun: true,
      validateOnly: true,
      categoryLimit: 5,
      productLimit: 10,
      variantLimit: 20,
      log: (_) {},
    );

    final loader = CatalogDatasetLoader(config);
    final forest = await loader.loadCategoryForest();
    final categoryIndex = CatalogEtl.buildCategoryIndex(forest);
    final products = await loader.loadAllProducts();
    final variants = await loader.loadAllVariants();
    final etl = CatalogEtl(categoryById: categoryIndex);

    final slice = DemoSliceSelector(
      categoryLimit: 5,
      productLimit: 10,
      variantLimit: 20,
    ).select(
      allCategories: categoryIndex,
      sourceProducts: products,
      sourceVariants: variants,
      etl: etl,
    );

    expect(slice.categories, isNotEmpty);
    expect(slice.products, isNotEmpty);
    expect(slice.variants, isNotEmpty);

    final repo = MemoryCatalogRepository(
      categories: slice.categories,
      products: slice.products,
      variants: slice.variants,
    );

    final page = await repo.listProducts(
      const CatalogListQuery(limit: 5, primaryCategoryId: '7'),
    );
    expect(page.items, isNotEmpty);

    final variantsForProduct =
        await repo.getVariantsForProduct(slice.products.first.id);
    expect(variantsForProduct, isNotEmpty);
  });

  test('Pipeline dry-run on mini fixture', () async {
    final config = CatalogImportConfig(
      dataRoot: _fixtureRoot(),
      dryRun: true,
      validateOnly: false,
      outputDir: '${Directory.current.path}/tools/catalog_import/out/test',
      categoryLimit: 5,
      productLimit: 10,
      variantLimit: 20,
      log: (_) {},
    );

    final result = await CatalogImportPipeline(config).run();
    expect(result.ok, isTrue);
    expect(result.importResult, isNotNull);
    expect(result.importResult!.dryRun, isTrue);
    expect(result.importResult!.outputPath, isNotNull);
  });

  test(
    'Full dataset validation when CATALOG_DATA_ROOT is set',
    () async {
      final root = Platform.environment['CATALOG_DATA_ROOT'] ??
          '/Users/itayamar/catalog-working';
      final config = CatalogImportConfig(
        dataRoot: root,
        validateOnly: true,
        log: (_) {},
      );
      if (!config.pathsExist) {
        // Skip on machines without local dataset
        return;
      }

      final result = await CatalogImportPipeline(config).run();
      expect(result.fullValidation.productCount, greaterThan(1000));
      expect(result.fullValidation.categoryCount, greaterThan(100));
      expect(result.slice.products.length, lessThanOrEqualTo(100));
      expect(result.slice.variants.length, lessThanOrEqualTo(300));
    },
    skip: !File('/Users/itayamar/catalog-working/normalized/products.jsonl')
        .existsSync(),
  );
}
