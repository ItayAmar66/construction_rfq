/// Import metadata (`catalogMeta/current`).
class CatalogMeta {
  const CatalogMeta({
    required this.version,
    this.productCount = 0,
    this.variantCount = 0,
    this.categoryCount = 0,
    this.importedAt,
    this.imageBasePath = 'catalog/images',
    this.searchMode = 'firestore',
    this.isDemoSlice = false,
  });

  final String version;
  final int productCount;
  final int variantCount;
  final int categoryCount;
  final DateTime? importedAt;
  final String imageBasePath;
  final String searchMode;
  final bool isDemoSlice;

  bool get isImported => version.isNotEmpty && productCount > 0;
}
