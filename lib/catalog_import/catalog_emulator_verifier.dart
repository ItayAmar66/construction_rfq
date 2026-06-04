import 'dart:convert';
import 'dart:io';

import '../utils/catalog_constants.dart';
import 'catalog_firestore_backend.dart';
import 'import_config.dart';

/// Post-import integrity checks against Firestore (emulator).
class CatalogEmulatorVerifier {
  CatalogEmulatorVerifier({
    required this.config,
    required this.backend,
  });

  final CatalogImportConfig config;
  final CatalogFirestoreBackend backend;

  static const expectedCategories = 418;
  static const expectedProducts = 11149;
  static const expectedVariants = 31551;

  Future<CatalogVerificationResult> run() async {
    config.log('Verifying catalog in Firestore...');

    final categoryCount = await backend.countCollection(
      CatalogConstants.categoriesCollection,
    );
    final productCount = await backend.countCollection(
      CatalogConstants.productsCollection,
    );
    final variantCount = await backend.countCollection(
      CatalogConstants.variantsCollection,
    );

    final metaData = await backend.getDocument(
      CatalogConstants.metaCollection,
      CatalogConstants.metaCurrentDocId,
    );

    final errors = <String>[];
    final warnings = <String>[];

    if (categoryCount != expectedCategories) {
      errors.add(
        'category count $categoryCount != expected $expectedCategories',
      );
    }
    if (productCount != expectedProducts) {
      errors.add('product count $productCount != expected $expectedProducts');
    }
    if (variantCount != expectedVariants) {
      errors.add('variant count $variantCount != expected $expectedVariants');
    }

    if (metaData == null) {
      errors.add('catalogMeta/current missing');
    } else {
      final mc = _asInt(metaData['categoryCount']);
      final mp = _asInt(metaData['productCount']);
      final mv = _asInt(metaData['variantCount']);
      if (mc != categoryCount) {
        errors.add('meta.categoryCount $mc != actual $categoryCount');
      }
      if (mp != productCount) {
        errors.add('meta.productCount $mp != actual $productCount');
      }
      if (mv != variantCount) {
        errors.add('meta.variantCount $mv != actual $variantCount');
      }
    }

    final orphanVariants = await _countOrphanVariants();
    if (orphanVariants > 0) {
      errors.add('$orphanVariants variants reference missing productId');
    }

    final productsMissingCategory = await _countProductsWithoutCategories();
    if (productsMissingCategory > 0) {
      warnings.add(
        '$productsMissingCategory products have empty categoryIds (known dataset issue)',
      );
    }

    final passed = errors.isEmpty;
    final summary = {
      'passed': passed,
      'categoryCount': categoryCount,
      'productCount': productCount,
      'variantCount': variantCount,
      'expectedCategories': expectedCategories,
      'expectedProducts': expectedProducts,
      'expectedVariants': expectedVariants,
      'orphanVariants': orphanVariants,
      'productsWithoutCategories': productsMissingCategory,
      'meta': metaData,
      'errors': errors,
      'warnings': warnings,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final outDir = Directory(
      '${config.outputDir ?? 'tools/catalog_import/out'}/emulator_verification',
    );
    await outDir.create(recursive: true);
    await File('${outDir.path}/summary.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    config.log('Verification ${passed ? 'PASS' : 'FAIL'} → ${outDir.path}/summary.json');

    return CatalogVerificationResult(
      passed: passed,
      categoryCount: categoryCount,
      productCount: productCount,
      variantCount: variantCount,
      errors: errors,
      warnings: warnings,
      summaryPath: '${outDir.path}/summary.json',
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<int> _countOrphanVariants() async {
    final productIds = <String>{};
    String? pageToken;
    do {
      final page = await backend.listCollectionPage(
        CatalogConstants.productsCollection,
        pageSize: 500,
        pageToken: pageToken,
      );
      for (final doc in page.docs) {
        productIds.add(doc.key);
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    var orphans = 0;
    pageToken = null;
    do {
      final page = await backend.listCollectionPage(
        CatalogConstants.variantsCollection,
        pageSize: 500,
        pageToken: pageToken,
      );
      for (final doc in page.docs) {
        final pid = doc.value['productId']?.toString() ?? '';
        if (pid.isEmpty || !productIds.contains(pid)) {
          orphans++;
        }
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return orphans;
  }

  Future<int> _countProductsWithoutCategories() async {
    var count = 0;
    String? pageToken;
    do {
      final page = await backend.listCollectionPage(
        CatalogConstants.productsCollection,
        pageSize: 500,
        pageToken: pageToken,
      );
      for (final doc in page.docs) {
        final ids = doc.value['categoryIds'];
        if (ids is! List || ids.isEmpty) count++;
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return count;
  }
}

class CatalogVerificationResult {
  const CatalogVerificationResult({
    required this.passed,
    required this.categoryCount,
    required this.productCount,
    required this.variantCount,
    required this.errors,
    required this.warnings,
    required this.summaryPath,
  });

  final bool passed;
  final int categoryCount;
  final int productCount;
  final int variantCount;
  final List<String> errors;
  final List<String> warnings;
  final String summaryPath;
}
