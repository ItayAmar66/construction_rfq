/// Required search/index fields for production light verify on active variants.
abstract final class CatalogVariantLightVerifyFields {
  static const requiredFields = [
    'displayNameLower',
    'categoryIds',
    'searchTokens',
    'isActive',
  ];

  /// Validates an active variant sample from Firestore.
  ///
  /// [skuLower] is optional — SKU-less catalog items omit it or use empty string.
  static List<String> errorsForActiveSample(
    Map<String, dynamic> sample, {
    String errorPrefix = 'light verify',
  }) {
    final errors = <String>[];

    for (final field in requiredFields) {
      if (!sample.containsKey(field) || sample[field] == null) {
        errors.add('$errorPrefix: active sample missing $field');
      }
    }

    if (sample['isActive'] != true) {
      errors.add('$errorPrefix: sample variant isActive != true');
    }

    final skuLower = sample['skuLower'];
    if (skuLower != null && skuLower is! String) {
      errors.add('$errorPrefix: active sample skuLower is not a string');
    }

    return errors;
  }
}
