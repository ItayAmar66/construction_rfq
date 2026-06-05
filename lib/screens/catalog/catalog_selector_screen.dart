import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/catalog_rfq_analytics.dart';
import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../providers/catalog_selector_provider.dart';
import '../../utils/app_spacing.dart';
import '../../utils/catalog_search_error_helper.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/catalog/catalog_variant_result_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/procurement_panel.dart';

/// Catalog variant picker for future RFQ lines (not wired to live RFQ create).
class CatalogSelectorScreen extends ConsumerStatefulWidget {
  const CatalogSelectorScreen({
    super.key,
    this.embeddedInSheet = false,
    this.onDraftSelected,
  });

  final bool embeddedInSheet;
  final ValueChanged<CatalogRfqLineDraft>? onDraftSelected;

  @override
  ConsumerState<CatalogSelectorScreen> createState() =>
      _CatalogSelectorScreenState();
}

class _CatalogSelectorScreenState extends ConsumerState<CatalogSelectorScreen> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogRfqAnalyticsProvider).track(
            CatalogRfqEventNames.selectorOpened,
          );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value, CatalogSelectorNotifier notifier) {
    _searchDebounce?.cancel();
    if (value.isEmpty) {
      notifier.setSearchText('');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) notifier.setSearchText(value);
    });
  }

  void _handleSelect(CatalogRfqLineDraft draft) {
    ref.read(catalogRfqAnalyticsProvider).track(
          CatalogRfqEventNames.catalogItemSelected,
          {'variantId': draft.variantId},
        );
    widget.onDraftSelected?.call(draft);
    if (GoRouter.maybeOf(context) != null) {
      context.pop(draft);
    } else {
      Navigator.of(context).pop(draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogSelectorProvider);
    final notifier = ref.read(catalogSelectorProvider.notifier);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: HebrewStrings.catalogSelectorSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        notifier.setSearchText('');
                      },
                    )
                  : null,
            ),
            onSubmitted: notifier.setSearchText,
            onChanged: (value) => _scheduleSearch(value, notifier),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ProcurementScreenIntro(
            title: HebrewStrings.catalogSelectorTitle,
            subtitle: HebrewStrings.catalogSelectorPromptHint,
            icon: Icons.manage_search_outlined,
          ),
        ),
        if (state.isLoadingCategories)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingView(),
          )
        else if (state.categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: FilterChip(
                    label: const Text(HebrewStrings.allCategories),
                    selected: state.selectedCategoryId == null,
                    onSelected: (_) => notifier.selectCategory(null),
                  ),
                ),
                for (final cat in state.categories.take(40))
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(cat.name),
                      selected: state.selectedCategoryId == cat.id,
                      onSelected: (_) => notifier.selectCategory(cat.id),
                    ),
                  ),
              ],
            ),
          ),
        if (state.selectedCategoryId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            HebrewStrings.catalogSelectedCategory,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            HebrewStrings.catalogBrowsingCategory(
                              _selectedCategoryLabel(state),
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        notifier.selectCategory(null);
                        if (_searchController.text.isEmpty) {
                          _searchController.clear();
                        }
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text(HebrewStrings.catalogClearCategory),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (state.isLoadingResults)
          const LinearProgressIndicator(minHeight: 2),
        if (!state.hasActiveQuery && state.recentSearches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  HebrewStrings.catalogRecentSearches,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: state.recentSearches
                      .map(
                        (term) => ActionChip(
                          label: Text(term),
                          onPressed: () {
                            _searchController.text = term;
                            notifier.setSearchText(term);
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        if (!state.hasActiveQuery && state.recentCategoryIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  HebrewStrings.catalogQuickCategories,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final id in state.recentCategoryIds)
                      if (state.categories.any((c) => c.id == id))
                        ActionChip(
                          label: Text(
                            state.categories
                                .firstWhere((c) => c.id == id)
                                .name,
                          ),
                          onPressed: () => notifier.selectCategory(id),
                        ),
                  ],
                ),
              ],
            ),
          ),
        if (state.usingDemoFallback)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.secondaryContainer
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        HebrewStrings.catalogDemoFallbackBanner,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ErrorMessage(
                  message: CatalogSearchErrorHelper.headline(state.errorMessage),
                  onRetry: () => notifier.initialize(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  CatalogSearchErrorHelper.hint(
                    showDebug: CatalogSearchErrorHelper.shouldShowDebugHint(
                      state.errorMessage,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (widget.embeddedInSheet) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    HebrewStrings.catalogSearchManualFallbackHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        Expanded(child: _buildResults(state, notifier)),
      ],
    );

    if (widget.embeddedInSheet) {
      return Material(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        HebrewStrings.catalogSelectorTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(HebrewStrings.catalogSelectorTitle),
      ),
      body: SafeArea(child: body),
    );
  }

  String _selectedCategoryLabel(CatalogSelectorState state) {
    final id = state.selectedCategoryId;
    if (id == null) return '';
    for (final category in state.categories) {
      if (category.id == id) return category.name;
    }
    return id;
  }

  Widget _buildResults(CatalogSelectorState state, CatalogSelectorNotifier notifier) {
    if (state.isLoadingResults && state.hits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!state.hasActiveQuery) {
      return EmptyState(
        message: HebrewStrings.catalogSelectorPrompt,
        icon: Icons.manage_search_outlined,
        hint: state.recentSearches.isEmpty
            ? HebrewStrings.catalogSelectorPromptHint
            : 'בחר חיפוש אחרון או קטגוריה מהירה',
      );
    }

    if (state.hits.isEmpty) {
      return EmptyState(
        message: HebrewStrings.catalogSelectorEmpty,
        icon: Icons.search_off_outlined,
        hint: state.recentSearches.length > 1
            ? 'נסה: ${state.recentSearches.skip(1).take(2).join(' · ')}'
            : HebrewStrings.catalogSelectorEmptyHint,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: state.hits.length,
            itemBuilder: (context, index) {
              final hit = state.hits[index];
              return CatalogVariantResultCard(
                hit: hit,
                onSelect: () =>
                    _handleSelect(CatalogRfqLineDraft.fromSearchHit(hit)),
              );
            },
          ),
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: OutlinedButton(
              onPressed: state.isLoadingMore ? null : notifier.loadMore,
              child: state.isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(HebrewStrings.loadMore),
            ),
          ),
      ],
    );
  }
}
