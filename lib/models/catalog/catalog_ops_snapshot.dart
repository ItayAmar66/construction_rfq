import 'catalog_meta.dart';

/// Read-only catalog ops view for debug/admin screens.
class CatalogOpsSnapshot {
  const CatalogOpsSnapshot({
    required this.meta,
    this.warnings = const [],
    this.loadedAt,
  });

  final CatalogMeta meta;
  final List<String> warnings;
  final DateTime? loadedAt;

  int get productCount => meta.productCount;
  int get variantCount => meta.variantCount;
  int get categoryCount => meta.categoryCount;
  String get version => meta.version;
  String get searchMode => meta.searchMode;
  DateTime? get importedAt => meta.importedAt;
  bool get isDemoSlice => meta.isDemoSlice;

  factory CatalogOpsSnapshot.fromMeta(
    CatalogMeta meta, {
    DateTime? loadedAt,
  }) {
    final warnings = <String>[];
    if (!meta.isImported) {
      warnings.add('Catalog not imported — counts may be zero.');
    }
    if (meta.variantCount > 0 && meta.variantCount < 1000) {
      warnings.add('Variant count looks like a demo slice (< 1,000).');
    }
    if (meta.searchMode != 'firestore') {
      warnings.add('Unexpected searchMode: ${meta.searchMode}');
    }
    return CatalogOpsSnapshot(
      meta: meta,
      warnings: warnings,
      loadedAt: loadedAt ?? DateTime.now(),
    );
  }
}
