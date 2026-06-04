/// Filters for listing catalog products.
class CatalogListQuery {
  const CatalogListQuery({
    this.categoryId,
    this.primaryCategoryId,
    this.activeOnly = true,
    this.searchPrefix,
    this.searchToken,
    this.limit = 24,
    this.startAfterNameLower,
    this.startAfterId,
  });

  final String? categoryId;
  final String? primaryCategoryId;
  final bool activeOnly;
  final String? searchPrefix;
  final String? searchToken;
  final int limit;
  final String? startAfterNameLower;
  final String? startAfterId;

  CatalogListQuery copyWith({
    String? startAfterNameLower,
    String? startAfterId,
  }) {
    return CatalogListQuery(
      categoryId: categoryId,
      primaryCategoryId: primaryCategoryId,
      activeOnly: activeOnly,
      searchPrefix: searchPrefix,
      searchToken: searchToken,
      limit: limit,
      startAfterNameLower: startAfterNameLower ?? this.startAfterNameLower,
      startAfterId: startAfterId ?? this.startAfterId,
    );
  }
}
