import 'dart:convert';
import 'dart:io';

import '../utils/catalog_constants.dart';
import 'catalog_firestore_backend.dart';
import 'catalog_variant_search_field_verifier.dart';
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
    if (config.verifyProduction) {
      config.log(
        'Production verify throttling: listPageSize=${config.listPageSize}, '
        'readPageDelayMs=${config.readPageDelayMs}, maxRetries=${config.maxRetries}',
      );
    }

    config.log('Counting catalogCategories...');
    final categoryCount = await backend.countCollection(
      CatalogConstants.categoriesCollection,
    );
    config.log('catalogCategories: $categoryCount / $expectedCategories');
    config.log('Counting catalogProducts...');
    final productCount = await backend.countCollection(
      CatalogConstants.productsCollection,
    );
    config.log('catalogProducts: $productCount / $expectedProducts');
    config.log('Counting catalogVariants...');
    final variantCount = await backend.countCollection(
      CatalogConstants.variantsCollection,
    );
    config.log('catalogVariants: $variantCount / $expectedVariants');

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

    final searchFields = await _verifyVariantSearchFields();
    if (!searchFields.passed) {
      errors.add(
        'variant search fields: ${searchFields.variantsFailed} of '
        '${searchFields.variantsChecked} failed validation',
      );
      for (final sample in searchFields.sampleErrors.take(10)) {
        errors.add('searchFields: $sample');
      }
    }

    Map<String, dynamic>? querySmoke;
    if (config.verifyProduction) {
      querySmoke = await _verifyProductionQuerySmoke(errors);
    }

    final passed = errors.isEmpty;
    final summary = {
      'passed': passed,
      'target': config.verifyProduction ? 'production' : 'emulator',
      'firebaseProjectId': config.firebaseProjectId,
      'categoryCount': categoryCount,
      'productCount': productCount,
      'variantCount': variantCount,
      'expectedCategories': expectedCategories,
      'expectedProducts': expectedProducts,
      'expectedVariants': expectedVariants,
      'orphanVariants': orphanVariants,
      'productsWithoutCategories': productsMissingCategory,
      'searchFields': searchFields.toJson(),
      if (querySmoke != null) 'querySmoke': querySmoke,
      'meta': metaData,
      'errors': errors,
      'warnings': warnings,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    final outDir = Directory(
      '${config.outputDir ?? 'tools/catalog_import/out'}/${config.verificationOutputSubdir}',
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
      searchFieldsPassed: searchFields.passed,
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

  Future<CatalogVariantSearchFieldReport> _verifyVariantSearchFields() async {
    final docs = <MapEntry<String, Map<String, dynamic>>>[];
    String? pageToken;
    do {
      final page = await backend.listCollectionPage(
        CatalogConstants.variantsCollection,
        pageToken: pageToken,
      );
      for (final doc in page.docs) {
        docs.add(MapEntry(doc.key, doc.value));
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    config.log(
      'Verifying search fields on ${docs.length} emulator variants...',
    );
    return CatalogVariantSearchFieldVerifier.verifyRawMaps(docs);
  }

  Future<Map<String, dynamic>> _verifyProductionQuerySmoke(
    List<String> errors,
  ) async {
    final checks = <String, dynamic>{};
    const requiredFields = [
      'displayNameLower',
      'categoryIds',
      'searchTokens',
      'isActive',
    ];

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
        'limit': 5,
      },
    });
    checks['activeVariantsSampleCount'] = activeHits.length;
    if (activeHits.isEmpty) {
      errors.add('production query smoke: no active variants returned');
    } else {
      final sample = activeHits.first.value;
      for (final field in requiredFields) {
        if (!sample.containsKey(field) || sample[field] == null) {
          errors.add('production query smoke: sample missing $field');
        }
      }

      final categoryIds = sample['categoryIds'];
      if (categoryIds is List && categoryIds.isNotEmpty) {
        final categoryId = categoryIds.first.toString();
        final categoryHits = await backend.runStructuredQuery({
          'structuredQuery': {
            'from': [
              {'collectionId': CatalogConstants.variantsCollection},
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'categoryIds'},
                'op': 'ARRAY_CONTAINS',
                'value': {'stringValue': categoryId},
              },
            },
            'limit': 5,
          },
        });
        checks['categoryBrowseSampleCount'] = categoryHits.length;
        checks['categoryBrowseSampleId'] = categoryId;
        if (categoryHits.isEmpty) {
          errors.add(
            'production query smoke: categoryIds browse returned no hits for $categoryId',
          );
        }
      } else {
        errors.add('production query smoke: sample variant has no categoryIds');
      }

      final tokens = sample['searchTokens'];
      if (tokens is List && tokens.isNotEmpty) {
        final token = tokens.first.toString();
        final textHits = await backend.runStructuredQuery({
          'structuredQuery': {
            'from': [
              {'collectionId': CatalogConstants.variantsCollection},
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'searchTokens'},
                'op': 'ARRAY_CONTAINS',
                'value': {'stringValue': token},
              },
            },
            'limit': 5,
          },
        });
        checks['textSearchSampleCount'] = textHits.length;
        checks['textSearchSampleToken'] = token;
        if (textHits.isEmpty) {
          errors.add(
            'production query smoke: searchTokens query returned no hits for $token',
          );
        }
      } else {
        errors.add('production query smoke: sample variant has no searchTokens');
      }

      final skuLower = sample['skuLower']?.toString() ?? '';
      if (skuLower.isNotEmpty) {
        checks['skuLowerSample'] = skuLower;
      }
    }

    checks['passed'] = !errors.any((e) => e.startsWith('production query smoke'));
    return checks;
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
    this.searchFieldsPassed = true,
  });

  final bool passed;
  final int categoryCount;
  final int productCount;
  final int variantCount;
  final List<String> errors;
  final List<String> warnings;
  final String summaryPath;
  final bool searchFieldsPassed;
}
