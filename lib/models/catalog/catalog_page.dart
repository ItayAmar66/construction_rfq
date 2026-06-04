/// Paged result from [CatalogRepository].
class CatalogPage<T> {
  const CatalogPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  static CatalogPage<T> empty<T>() => CatalogPage<T>(items: const []);
}
