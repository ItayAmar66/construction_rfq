import 'dart:convert';
import 'dart:io';

import '../utils/catalog_constants.dart';
import 'catalog_emulator_verifier.dart';
import 'catalog_firestore_backend.dart';
import 'import_config.dart';

/// Minimal read-only production health check (Spark/free tier friendly).
///
/// Avoids full collection counts and multi-page scans.
class CatalogProductionLightVerifier {
  CatalogProductionLightVerifier({
    required this.config,
    required this.backend,
  });

  final CatalogImportConfig config;
  final CatalogFirestoreBackend backend;

  static const _requiredVariantFields = [
    'displayNameLower',
    'skuLower',
    'categoryIds',
    'searchTokens',
    'isActive',
  ];

  Future<CatalogVerificationResult> run() async {
    config.log('Light production verify (read-only, no full scans)...');
    config.log(
      'Throttling: listPageSize=${config.listPageSize}, '
      'readPageDelayMs=${config.readPageDelayMs}, maxRetries=${config.maxRetries}',
    );

    final errors = <String>[];
    final warnings = <String>[];

    final metaData = await backend.getDocument(
      CatalogConstants.metaCollection,
      CatalogConstants.metaCurrentDocId,
    );
    if (metaData == null) {
      warnings.add(
        'partial import: catalogMeta/current not written yet (import incomplete)',
      );
    } else {
      config.log(
        'catalogMeta/current: categories=${metaData['categoryCount']} '
        'products=${metaData['productCount']} variants=${metaData['variantCount']}',
      );
    }

    final categoryPage = await backend.listCollectionPage(
      CatalogConstants.categoriesCollection,
      pageSize: 1,
    );
    if (categoryPage.docs.isEmpty) {
      errors.add('catalogCategories first page is empty');
    } else {
      config.log('catalogCategories first page: ${categoryPage.docs.length} doc(s)');
    }

    final productPage = await backend.listCollectionPage(
      CatalogConstants.productsCollection,
      pageSize: 1,
    );
    if (productPage.docs.isEmpty) {
      errors.add('catalogProducts first page is empty');
    } else {
      config.log('catalogProducts first page: ${productPage.docs.length} doc(s)');
    }

    final variantPage = await backend.listCollectionPage(
      CatalogConstants.variantsCollection,
      pageSize: 1,
    );
    if (variantPage.docs.isEmpty) {
      errors.add('catalogVariants first page is empty');
    } else {
      config.log('catalogVariants first page: ${variantPage.docs.length} doc(s)');
    }

    final activeHits = await backend.runStructuredQuery({
      'structuredQuery': {
        'from': [
          {'collectionId': CatalogConstants.variantsCollection},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'isActive'},
            'op': 'EQUAL',
            'value': {'booleanValue': true},
          },
        },
        'limit': 1,
      },
    });

    Map<String, dynamic>? sampleVariant;
    if (activeHits.isEmpty) {
      errors.add('light verify: no active variant sample returned');
    } else {
      sampleVariant = activeHits.first.value;
      for (final field in _requiredVariantFields) {
        if (!sampleVariant.containsKey(field) || sampleVariant[field] == null) {
          errors.add('light verify: active sample missing $field');
        }
      }
      if (sampleVariant['isActive'] != true) {
        errors.add('light verify: sample variant isActive != true');
      }
    }

    final passed = errors.isEmpty;
    final summary = {
      'passed': passed,
      'mode': 'production-light',
      'target': 'production',
      'firebaseProjectId': config.firebaseProjectId,
      'metaPresent': metaData != null,
      'meta': metaData,
      'firstPageCounts': {
        'categories': categoryPage.docs.length,
        'products': productPage.docs.length,
        'variants': variantPage.docs.length,
      },
      'activeVariantSample': sampleVariant,
      'errors': errors,
      'warnings': warnings,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final outDir = Directory(
      '${config.outputDir ?? 'tools/catalog_import/out'}/${config.verificationOutputSubdir}',
    );
    await outDir.create(recursive: true);
    final summaryPath = '${outDir.path}/summary.json';
    await File(summaryPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    config.log('Light verify ${passed ? 'PASS' : 'FAIL'} → $summaryPath');

    return CatalogVerificationResult(
      passed: passed,
      categoryCount: categoryPage.docs.isNotEmpty ? 1 : 0,
      productCount: productPage.docs.isNotEmpty ? 1 : 0,
      variantCount: variantPage.docs.isNotEmpty ? 1 : 0,
      errors: errors,
      warnings: warnings,
      summaryPath: summaryPath,
      searchFieldsPassed: passed,
    );
  }
}
