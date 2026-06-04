/// Sort order for variant search/browse results.
enum CatalogSearchSort {
  /// Stable browse order (sortOrder, then name).
  sortOrder,

  /// Alphabetical by normalized display/name.
  nameLower,
}

/// Query for [CatalogSearchRepository] variant search and category browse.
class CatalogSearchQuery {
  const CatalogSearchQuery({
    this.text,
    this.categoryId,
    this.limit = 24,
    this.pageToken,
    this.includeInactive = false,
    this.sort = CatalogSearchSort.nameLower,
  });

  final String? text;
  final String? categoryId;
  final int limit;
  final String? pageToken;
  final bool includeInactive;
  final CatalogSearchSort sort;

  bool get hasText => text != null && text!.trim().isNotEmpty;
  bool get hasCategory =>
      categoryId != null && categoryId!.trim().isNotEmpty;

  int get effectiveLimit => limit.clamp(1, 50);

  CatalogSearchQuery copyWith({
    String? pageToken,
    int? limit,
  }) {
    return CatalogSearchQuery(
      text: text,
      categoryId: categoryId,
      limit: limit ?? this.limit,
      pageToken: pageToken ?? this.pageToken,
      includeInactive: includeInactive,
      sort: sort,
    );
  }
}
