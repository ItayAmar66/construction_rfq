import 'catalog_search_hit.dart';

/// Paginated variant search/browse page.
class CatalogSearchPage {
  const CatalogSearchPage({
    required this.hits,
    this.nextPageToken,
    this.hasMore = false,
  });

  final List<CatalogSearchHit> hits;
  final String? nextPageToken;
  final bool hasMore;

  static const empty = CatalogSearchPage(hits: []);
}
