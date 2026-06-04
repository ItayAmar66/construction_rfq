import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/catalog_constants.dart';
import 'import_config.dart';

/// Post-import integrity checks against Firestore (emulator).
class CatalogEmulatorVerifier {
  CatalogEmulatorVerifier({
    required this.config,
    required this.db,
  });

  final CatalogImportConfig config;
  final FirebaseFirestore db;

  static const expectedCategories = 418;
  static const expectedProducts = 11149;
  static const expectedVariants = 31551;

  Future<CatalogVerificationResult> run() async {
    config.log('Verifying catalog in Firestore...');

    final categoryCount = await _countCollection(
      CatalogConstants.categoriesCollection,
    );
    final productCount = await _countCollection(
      CatalogConstants.productsCollection,
    );
    final variantCount = await _countCollection(
      CatalogConstants.variantsCollection,
    );

    final metaSnap = await db
        .collection(CatalogConstants.metaCollection)
        .doc(CatalogConstants.metaCurrentDocId)
        .get();

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

    Map<String, dynamic>? metaData;
    if (!metaSnap.exists) {
      errors.add('catalogMeta/current missing');
    } else {
      metaData = metaSnap.data();
      final mc = metaData?['categoryCount'] as int?;
      final mp = metaData?['productCount'] as int?;
      final mv = metaData?['variantCount'] as int?;
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

  Future<int> _countCollection(String collection) async {
    final agg = await db.collection(collection).count().get();
    return agg.count ?? 0;
  }

  Future<int> _countOrphanVariants() async {
    final productIds = <String>{};
    const pageSize = 500;
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q =
          db.collection(CatalogConstants.productsCollection).limit(pageSize);
      if (last != null) {
        q = q.startAfterDocument(last);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        productIds.add(doc.id);
      }
      last = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }

    var orphans = 0;
    last = null;
    while (true) {
      Query<Map<String, dynamic>> q =
          db.collection(CatalogConstants.variantsCollection).limit(pageSize);
      if (last != null) {
        q = q.startAfterDocument(last);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        final pid = doc.data()['productId']?.toString() ?? '';
        if (pid.isEmpty || !productIds.contains(pid)) {
          orphans++;
        }
      }
      last = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }
    return orphans;
  }

  Future<int> _countProductsWithoutCategories() async {
    var count = 0;
    const pageSize = 500;
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q =
          db.collection(CatalogConstants.productsCollection).limit(pageSize);
      if (last != null) {
        q = q.startAfterDocument(last);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        final ids = doc.data()['categoryIds'] as List?;
        if (ids == null || ids.isEmpty) count++;
      }
      last = snap.docs.last;
      if (snap.docs.length < pageSize) break;
    }
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
