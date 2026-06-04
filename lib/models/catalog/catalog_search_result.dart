import 'catalog_search_page.dart';

/// UI-ready search state (repository returns pages; callers map to this).
enum CatalogSearchStatus {
  idle,
  loading,
  success,
  error,
}

class CatalogSearchResult {
  const CatalogSearchResult({
    this.status = CatalogSearchStatus.idle,
    this.page,
    this.errorMessage,
  });

  final CatalogSearchStatus status;
  final CatalogSearchPage? page;
  final String? errorMessage;

  bool get isLoading => status == CatalogSearchStatus.loading;
  bool get isSuccess => status == CatalogSearchStatus.success;
  bool get hasError => status == CatalogSearchStatus.error;

  CatalogSearchResult copyWith({
    CatalogSearchStatus? status,
    CatalogSearchPage? page,
    String? errorMessage,
  }) {
    return CatalogSearchResult(
      status: status ?? this.status,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }

  static CatalogSearchResult loading() => const CatalogSearchResult(
        status: CatalogSearchStatus.loading,
      );

  static CatalogSearchResult success(CatalogSearchPage page) =>
      CatalogSearchResult(
        status: CatalogSearchStatus.success,
        page: page,
      );

  static CatalogSearchResult failure(String message) => CatalogSearchResult(
        status: CatalogSearchStatus.error,
        errorMessage: message,
      );
}
