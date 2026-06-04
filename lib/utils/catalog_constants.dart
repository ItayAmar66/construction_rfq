/// Firestore collection names for the v2 catalog (parallel to legacy [AppConstants.productsCollection]).
abstract final class CatalogConstants {
  static const String categoriesCollection = 'catalogCategories';
  static const String productsCollection = 'catalogProducts';
  static const String variantsCollection = 'catalogVariants';
  static const String metaCollection = 'catalogMeta';
  static const String metaCurrentDocId = 'current';

  static const int defaultPageSize = 24;
  static const int maxSearchTokens = 30;

  /// Demo import limits (validation slice only).
  static const int demoCategoryLimit = 20;
  static const int demoProductLimit = 100;
  static const int demoVariantLimit = 300;
}
