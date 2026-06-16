import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog/catalog_availability.dart';
import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_search_hit.dart';
import '../models/catalog/catalog_search_page.dart';
import '../models/catalog/catalog_search_query.dart';
import '../repositories/catalog_search/catalog_search_repository.dart';
import '../utils/catalog_search_constants.dart';
import '../utils/user_facing_error.dart';
import 'catalog_search_providers.dart';

class CatalogSelectorState {
  const CatalogSelectorState({
    this.categories = const [],
    this.allCategories = const [],
    this.hits = const [],
    this.searchText = '',
    this.selectedCategoryId,
    this.isLoadingCategories = false,
    this.isLoadingAllCategories = false,
    this.isLoadingResults = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.hasMore = false,
    this.nextPageToken,
    this.recentSearches = const [],
    this.recentCategoryIds = const [],
    this.availability,
    this.initialBrowseLoaded = false,
    this.allCategoriesLoaded = false,
  });

  final List<CatalogCategory> categories;
  final List<CatalogCategory> allCategories;
  final List<CatalogSearchHit> hits;
  final String searchText;
  final String? selectedCategoryId;
  final bool isLoadingCategories;
  final bool isLoadingAllCategories;
  final bool isLoadingResults;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool hasMore;
  final String? nextPageToken;
  final List<String> recentSearches;
  final List<String> recentCategoryIds;
  final CatalogAvailability? availability;
  final bool initialBrowseLoaded;
  final bool allCategoriesLoaded;

  bool get catalogReady => availability?.isReady ?? false;

  bool get catalogPartial => availability?.isPartialImport ?? false;

  bool get hasActiveFilter =>
      searchText.trim().isNotEmpty ||
      (selectedCategoryId != null && selectedCategoryId!.isNotEmpty);

  int get loadedCount => hits.length;

  List<CatalogCategory> get pickerCategories =>
      allCategoriesLoaded && allCategories.isNotEmpty
          ? allCategories
          : categories;

  CatalogSelectorState copyWith({
    List<CatalogCategory>? categories,
    List<CatalogCategory>? allCategories,
    List<CatalogSearchHit>? hits,
    String? searchText,
    String? selectedCategoryId,
    bool clearCategory = false,
    bool? isLoadingCategories,
    bool? isLoadingAllCategories,
    bool? isLoadingResults,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    String? nextPageToken,
    bool clearPageToken = false,
    List<String>? recentSearches,
    List<String>? recentCategoryIds,
    CatalogAvailability? availability,
    bool? initialBrowseLoaded,
    bool? allCategoriesLoaded,
  }) {
    return CatalogSelectorState(
      categories: categories ?? this.categories,
      allCategories: allCategories ?? this.allCategories,
      hits: hits ?? this.hits,
      searchText: searchText ?? this.searchText,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingAllCategories:
          isLoadingAllCategories ?? this.isLoadingAllCategories,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      nextPageToken:
          clearPageToken ? null : (nextPageToken ?? this.nextPageToken),
      recentSearches: recentSearches ?? this.recentSearches,
      recentCategoryIds: recentCategoryIds ?? this.recentCategoryIds,
      availability: availability ?? this.availability,
      initialBrowseLoaded: initialBrowseLoaded ?? this.initialBrowseLoaded,
      allCategoriesLoaded: allCategoriesLoaded ?? this.allCategoriesLoaded,
    );
  }
}

class CatalogSelectorNotifier extends StateNotifier<CatalogSelectorState> {
  CatalogSelectorNotifier(this._repo) : super(const CatalogSelectorState()) {
    state = state.copyWith(
      recentSearches: List.of(_sessionRecentSearches),
      recentCategoryIds: List.of(_sessionRecentCategoryIds),
    );
  }

  final CatalogSearchRepository _repo;

  static const pageSize = CatalogSearchConstants.defaultPageSize;
  static const topCategoryLimit = 48;

  static final List<String> _sessionRecentSearches = [];
  static final List<String> _sessionRecentCategoryIds = [];

  @visibleForTesting
  static void clearSessionRecentsForTesting() {
    _sessionRecentSearches.clear();
    _sessionRecentCategoryIds.clear();
  }

  void _recordSearch(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 2) return;
    _sessionRecentSearches.remove(trimmed);
    _sessionRecentSearches.insert(0, trimmed);
    if (_sessionRecentSearches.length > 5) {
      _sessionRecentSearches.removeLast();
    }
    state = state.copyWith(recentSearches: List.of(_sessionRecentSearches));
  }

  void _recordCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return;
    _sessionRecentCategoryIds.remove(categoryId);
    _sessionRecentCategoryIds.insert(0, categoryId);
    if (_sessionRecentCategoryIds.length > 4) {
      _sessionRecentCategoryIds.removeLast();
    }
    state = state.copyWith(recentCategoryIds: List.of(_sessionRecentCategoryIds));
  }

  Future<void> initialize() async {
    if (state.initialBrowseLoaded && state.catalogReady) return;

    state = state.copyWith(
      isLoadingCategories: true,
      isLoadingResults: true,
      clearError: true,
    );
    try {
      final availability = await _repo
          .getCatalogAvailability()
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => CatalogAvailability.unavailable(
              reason: 'timeout',
            ),
          );
      state = state.copyWith(availability: availability);

      if (!availability.isReady) {
        state = state.copyWith(
          isLoadingCategories: false,
          isLoadingResults: false,
          hits: const [],
          hasMore: false,
          clearPageToken: true,
        );
        return;
      }

      final parallel = await Future.wait<Object>([
        _repo.getTopCategories(limit: topCategoryLimit),
        _fetchPage(),
      ]);
      final topCategories = parallel[0] as List<CatalogCategory>;
      final page = parallel[1] as CatalogSearchPage;

      state = state.copyWith(
        categories: topCategories,
        hits: page.hits,
        hasMore: page.hasMore,
        nextPageToken: page.nextPageToken,
        isLoadingCategories: false,
        isLoadingResults: false,
        initialBrowseLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingCategories: false,
        isLoadingResults: false,
        errorMessage: userFacingError(e),
        availability: CatalogAvailability.unavailable(reason: 'query_error'),
      );
    }
  }

  /// Loads full category tree lazily (e.g. for searchable picker).
  Future<List<CatalogCategory>> ensureAllCategories() async {
    if (state.allCategoriesLoaded && state.allCategories.isNotEmpty) {
      return state.allCategories;
    }
    state = state.copyWith(isLoadingAllCategories: true);
    try {
      final tree = await _repo.getCategoryTree();
      state = state.copyWith(
        allCategories: tree,
        allCategoriesLoaded: true,
        isLoadingAllCategories: false,
      );
      return tree;
    } catch (e) {
      state = state.copyWith(isLoadingAllCategories: false);
      rethrow;
    }
  }

  Future<void> setSearchText(String text) async {
    if (!state.catalogReady) return;
    if (text.trim().isNotEmpty) {
      _recordSearch(text);
    }
    state = state.copyWith(
      searchText: text,
      clearPageToken: true,
      hits: const [],
    );
    await _refreshResults();
  }

  Future<void> selectCategory(String? categoryId) async {
    if (!state.catalogReady) return;
    _recordCategory(categoryId);

    var categories = state.categories;
    if (categoryId != null &&
        categoryId.isNotEmpty &&
        !categories.any((c) => c.id == categoryId)) {
      await ensureAllCategories();
      final picked = state.allCategories
          .where((c) => c.id == categoryId)
          .toList();
      if (picked.isNotEmpty) {
        categories = [picked.first, ...categories];
      }
    }

    state = state.copyWith(
      categories: categories,
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
      clearPageToken: true,
      hits: const [],
    );
    await _refreshResults();
  }

  Future<void> loadMore() async {
    if (!state.catalogReady || !state.hasMore || state.isLoadingMore) {
      return;
    }
    if (state.nextPageToken == null) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _fetchPage(pageToken: state.nextPageToken);
      state = state.copyWith(
        hits: [...state.hits, ...page.hits],
        hasMore: page.hasMore,
        nextPageToken: page.nextPageToken,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: userFacingError(e),
      );
    }
  }

  Future<void> _refreshResults() async {
    if (!state.catalogReady) return;

    state = state.copyWith(isLoadingResults: true, clearError: true);
    try {
      final page = await _fetchPage();
      state = state.copyWith(
        hits: page.hits,
        hasMore: page.hasMore,
        nextPageToken: page.nextPageToken,
        isLoadingResults: false,
        initialBrowseLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingResults: false,
        errorMessage: userFacingError(e),
        hits: const [],
      );
    }
  }

  Future<CatalogSearchPage> _fetchPage({String? pageToken}) async {
    final query = CatalogSearchQuery(
      text: state.searchText.trim().isEmpty ? null : state.searchText.trim(),
      categoryId: state.selectedCategoryId,
      limit: pageSize,
      pageToken: pageToken,
    );

    final categoryOnly = state.selectedCategoryId != null &&
        state.selectedCategoryId!.isNotEmpty &&
        state.searchText.trim().isEmpty;

    if (categoryOnly) {
      return _repo.browseVariantsByCategory(query);
    }
    return _repo.searchVariants(query);
  }
}

final catalogSelectorProvider =
    StateNotifierProvider<CatalogSelectorNotifier, CatalogSelectorState>(
  (ref) {
    ref.keepAlive();
    final notifier =
        CatalogSelectorNotifier(ref.watch(catalogSearchRepositoryProvider));
    notifier.initialize();
    return notifier;
  },
);
