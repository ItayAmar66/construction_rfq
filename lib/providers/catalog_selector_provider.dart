import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog/catalog_category.dart';
import '../models/catalog/catalog_search_hit.dart';
import '../models/catalog/catalog_search_page.dart';
import '../models/catalog/catalog_search_query.dart';
import '../repositories/catalog_search/catalog_search_repository.dart';
import '../config/app_mode.dart';
import '../repositories/catalog_search/fallback_catalog_search_repository.dart';
import 'catalog_search_providers.dart';

class CatalogSelectorState {
  const CatalogSelectorState({
    this.categories = const [],
    this.hits = const [],
    this.searchText = '',
    this.selectedCategoryId,
    this.isLoadingCategories = false,
    this.isLoadingResults = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.hasMore = false,
    this.nextPageToken,
    this.recentSearches = const [],
    this.recentCategoryIds = const [],
    this.usingDemoFallback = false,
  });

  final List<CatalogCategory> categories;
  final List<CatalogSearchHit> hits;
  final String searchText;
  final String? selectedCategoryId;
  final bool isLoadingCategories;
  final bool isLoadingResults;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool hasMore;
  final String? nextPageToken;
  final List<String> recentSearches;
  final List<String> recentCategoryIds;
  final bool usingDemoFallback;

  bool get hasActiveQuery =>
      searchText.trim().isNotEmpty ||
      (selectedCategoryId != null && selectedCategoryId!.isNotEmpty);

  CatalogSelectorState copyWith({
    List<CatalogCategory>? categories,
    List<CatalogSearchHit>? hits,
    String? searchText,
    String? selectedCategoryId,
    bool clearCategory = false,
    bool? isLoadingCategories,
    bool? isLoadingResults,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    bool? hasMore,
    String? nextPageToken,
    bool clearPageToken = false,
    List<String>? recentSearches,
    List<String>? recentCategoryIds,
    bool? usingDemoFallback,
  }) {
    return CatalogSelectorState(
      categories: categories ?? this.categories,
      hits: hits ?? this.hits,
      searchText: searchText ?? this.searchText,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMore: hasMore ?? this.hasMore,
      nextPageToken:
          clearPageToken ? null : (nextPageToken ?? this.nextPageToken),
      recentSearches: recentSearches ?? this.recentSearches,
      recentCategoryIds: recentCategoryIds ?? this.recentCategoryIds,
      usingDemoFallback: usingDemoFallback ?? this.usingDemoFallback,
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

  static final List<String> _sessionRecentSearches = [];
  static final List<String> _sessionRecentCategoryIds = [];

  /// Clears in-memory session recents (widget tests only).
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

  void _syncFallbackFlag() {
    final using = AppMode.isDemoMode ||
        (_repo is FallbackCatalogSearchRepository &&
            (_repo as FallbackCatalogSearchRepository).usingFallback);
    if (using != state.usingDemoFallback) {
      state = state.copyWith(usingDemoFallback: using);
    }
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoadingCategories: true, clearError: true);
    try {
      final categories = await _repo.getCategoryTree();
      state = state.copyWith(
        categories: categories,
        isLoadingCategories: false,
      );
      _syncFallbackFlag();
    } catch (e) {
      state = state.copyWith(
        isLoadingCategories: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> setSearchText(String text) async {
    _recordSearch(text);
    state = state.copyWith(
      searchText: text,
      clearPageToken: true,
      hits: const [],
    );
    await _refreshResults();
  }

  Future<void> selectCategory(String? categoryId) async {
    _recordCategory(categoryId);
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
      clearPageToken: true,
      hits: const [],
    );
    await _refreshResults();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.nextPageToken == null) {
      return;
    }
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
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _refreshResults() async {
    if (!state.hasActiveQuery) {
      state = state.copyWith(
        hits: const [],
        hasMore: false,
        clearPageToken: true,
        isLoadingResults: false,
      );
      return;
    }

    state = state.copyWith(isLoadingResults: true, clearError: true);
    try {
      final page = await _fetchPage();
      state = state.copyWith(
        hits: page.hits,
        hasMore: page.hasMore,
        nextPageToken: page.nextPageToken,
        isLoadingResults: false,
      );
      _syncFallbackFlag();
    } catch (e) {
      state = state.copyWith(
        isLoadingResults: false,
        errorMessage: e.toString(),
        hits: const [],
      );
    }
  }

  Future<CatalogSearchPage> _fetchPage({String? pageToken}) async {
    final query = CatalogSearchQuery(
      text: state.searchText.trim().isEmpty ? null : state.searchText.trim(),
      categoryId: state.selectedCategoryId,
      limit: 24,
      pageToken: pageToken,
    );

    if (state.selectedCategoryId != null &&
        state.selectedCategoryId!.isNotEmpty &&
        state.searchText.trim().isEmpty) {
      return _repo.browseVariantsByCategory(query);
    }
    return _repo.searchVariants(query);
  }
}

final catalogSelectorProvider =
    StateNotifierProvider.autoDispose<CatalogSelectorNotifier, CatalogSelectorState>(
  (ref) {
    final notifier = CatalogSelectorNotifier(ref.watch(catalogSearchRepositoryProvider));
    notifier.initialize();
    return notifier;
  },
);
