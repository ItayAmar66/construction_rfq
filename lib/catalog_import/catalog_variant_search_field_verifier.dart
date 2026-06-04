import '../models/catalog/catalog_variant.dart';
import '../repositories/catalog/catalog_firestore_converter.dart';

/// Validates denormalized search fields on catalog variant documents.
abstract final class CatalogVariantSearchFieldVerifier {
  static const requiredVariantFields = [
    'isActive',
    'categoryIds',
    'searchTokens',
    'nameLower',
  ];

  /// Verifies a Firestore/import map for one variant.
  static List<String> errorsForMap(Map<String, dynamic> data) {
    final errors = <String>[];

    for (final key in requiredVariantFields) {
      if (!data.containsKey(key)) {
        errors.add('missing $key');
      }
    }

    final categoryIds = data['categoryIds'];
    if (categoryIds != null && categoryIds is! List) {
      errors.add('categoryIds is not a list');
    }

    final searchTokens = data['searchTokens'];
    if (searchTokens != null && searchTokens is! List) {
      errors.add('searchTokens is not a list');
    } else if (searchTokens is List && searchTokens.isEmpty) {
      errors.add('searchTokens is empty');
    }

    if (!data.containsKey('isActive')) {
      errors.add('missing isActive');
    }

    final displayName = data['displayName']?.toString() ?? '';
    if (displayName.isNotEmpty) {
      final lower = data['displayNameLower']?.toString() ?? '';
      if (lower.isEmpty) {
        errors.add('missing displayNameLower for displayName');
      }
    }

    final nameLower = data['nameLower']?.toString() ?? '';
    if (nameLower.isEmpty) {
      errors.add('nameLower is empty');
    }

    return errors;
  }

  static List<String> errorsForVariant(CatalogVariant variant) {
    return errorsForMap(CatalogFirestoreConverter.variantToMap(variant));
  }

  static CatalogVariantSearchFieldReport verifyAll(
    Iterable<CatalogVariant> variants, {
    int maxSampleErrors = 25,
  }) {
    var checked = 0;
    var failed = 0;
    final samples = <String>[];

    for (final variant in variants) {
      checked++;
      final errs = errorsForVariant(variant);
      if (errs.isNotEmpty) {
        failed++;
        if (samples.length < maxSampleErrors) {
          samples.add('${variant.id}: ${errs.join(', ')}');
        }
      }
    }

    return CatalogVariantSearchFieldReport(
      variantsChecked: checked,
      variantsFailed: failed,
      passed: failed == 0,
      sampleErrors: samples,
    );
  }

  static CatalogVariantSearchFieldReport verifyRawMaps(
    Iterable<MapEntry<String, Map<String, dynamic>>> docs, {
    int maxSampleErrors = 25,
  }) {
    var checked = 0;
    var failed = 0;
    final samples = <String>[];

    for (final doc in docs) {
      checked++;
      final errs = errorsForMap(doc.value);
      if (errs.isNotEmpty) {
        failed++;
        if (samples.length < maxSampleErrors) {
          samples.add('${doc.key}: ${errs.join(', ')}');
        }
      }
    }

    return CatalogVariantSearchFieldReport(
      variantsChecked: checked,
      variantsFailed: failed,
      passed: failed == 0,
      sampleErrors: samples,
    );
  }
}

class CatalogVariantSearchFieldReport {
  const CatalogVariantSearchFieldReport({
    required this.variantsChecked,
    required this.variantsFailed,
    required this.passed,
    this.sampleErrors = const [],
  });

  final int variantsChecked;
  final int variantsFailed;
  final bool passed;
  final List<String> sampleErrors;

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'variantsChecked': variantsChecked,
        'variantsFailed': variantsFailed,
        if (sampleErrors.isNotEmpty) 'sampleErrors': sampleErrors,
      };
}
