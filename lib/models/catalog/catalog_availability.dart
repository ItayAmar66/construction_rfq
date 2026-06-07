import 'catalog_meta.dart';

/// Whether the imported Firestore catalog is available for selector/search.
class CatalogAvailability {
  const CatalogAvailability({
    required this.isReady,
    this.hasMetaDoc = false,
    this.variantCount = 0,
    this.productCount = 0,
    this.categoryCount = 0,
    this.reason,
  });

  final bool isReady;
  final bool hasMetaDoc;
  final int variantCount;
  final int productCount;
  final int categoryCount;
  final String? reason;

  factory CatalogAvailability.fromMeta(CatalogMeta meta, {required bool hasDoc}) {
    final ready = hasDoc &&
        meta.version.isNotEmpty &&
        meta.variantCount > 0 &&
        meta.categoryCount > 0;
    return CatalogAvailability(
      isReady: ready,
      hasMetaDoc: hasDoc,
      variantCount: meta.variantCount,
      productCount: meta.productCount,
      categoryCount: meta.categoryCount,
      reason: ready ? null : _reasonFor(meta, hasDoc: hasDoc),
    );
  }

  factory CatalogAvailability.unavailable({String? reason}) {
    return CatalogAvailability(isReady: false, reason: reason ?? 'missing_meta');
  }

  static String? _reasonFor(CatalogMeta meta, {required bool hasDoc}) {
    if (!hasDoc) return 'missing_meta';
    if (meta.version.isEmpty) return 'missing_version';
    if (meta.variantCount <= 0) return 'empty_variants';
    if (meta.categoryCount <= 0) return 'empty_categories';
    return 'not_ready';
  }
}
