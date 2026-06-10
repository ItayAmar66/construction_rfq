import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/catalog_rfq_analytics.dart';
import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../models/catalog/catalog_search_hit.dart';
import '../../providers/catalog_selector_provider.dart';
import '../../providers/rfq_draft_provider.dart';
import '../../utils/app_spacing.dart';
import '../../utils/catalog_search_error_helper.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/catalog/catalog_category_picker.dart';
import '../../widgets/catalog/catalog_variant_detail_sheet.dart';
import '../../widgets/catalog/catalog_variant_result_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';

/// Real Firestore catalog: search, categories, variant list.
class CatalogSelectorScreen extends ConsumerStatefulWidget {
  const CatalogSelectorScreen({
    super.key,
    this.embeddedInSheet = false,
    this.standaloneMode = false,
    this.onDraftSelected,
    this.onItemAdded,
    this.appBar,
  });

  final bool embeddedInSheet;
  final bool standaloneMode;
  final ValueChanged<CatalogRfqLineDraft>? onDraftSelected;
  final Future<void> Function(CatalogRfqLineDraft)? onItemAdded;
  final PreferredSizeWidget? appBar;

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

  void _handleQuickAdd(CatalogSearchHit hit) {
    final draft = CatalogRfqLineDraft.fromSearchHit(hit);
    ref.read(catalogRfqAnalyticsProvider).track(
          CatalogRfqEventNames.catalogItemSelected,
          {'variantId': draft.variantId, 'source': 'quick_add'},
        );
    ref.read(rfqDraftProvider.notifier).quickAddCatalogVariant(draft);
  }

  Future<void> _handleOpenDetail(CatalogSearchHit hit) async {
    final draft = await CatalogVariantDetailSheet.show(context, hit: hit);
    if (draft == null || !mounted) return;
    await _handleSelect(draft);
  }

  Future<void> _handleSelect(CatalogRfqLineDraft draft) async {
    ref.read(catalogRfqAnalyticsProvider).track(
          CatalogRfqEventNames.catalogItemSelected,
          {'variantId': draft.variantId},
        );

    if (widget.onItemAdded != null) {
      await widget.onItemAdded!(draft);
      return;
    }

    widget.onDraftSelected?.call(draft);
    if (widget.embeddedInSheet) {
      Navigator.of(context).pop(draft);
    } else if (GoRouter.maybeOf(context) != null) {
      context.pop(draft);
    } else {
      Navigator.of(context).pop(draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogSelectorProvider);
    final notifier = ref.read(catalogSelectorProvider.notifier);
    final draftQuantities = ref.watch(catalogDraftQuantityByVariantProvider);

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
              hintText: HebrewStrings.catalogSearchHint,
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
        if (state.isLoadingCategories)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingView(),
          )
        else if (state.categories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              HebrewStrings.catalogCategoriesSection,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
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
                for (final id in state.recentCategoryIds)
                  if (state.categories.any((c) => c.id == id))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.sm,
                      ),
                      child: FilterChip(
                        label: Text(
                          state.categories.firstWhere((c) => c.id == id).name,
                        ),
                        selected: state.selectedCategoryId == id,
                        onSelected: (_) => notifier.selectCategory(id),
                      ),
                    ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ActionChip(
                    avatar: const Icon(Icons.unfold_more, size: 18),
                    label: Text(HebrewStrings.catalogAllCategoriesPicker),
                    onPressed: () async {
                      var categories = state.pickerCategories;
                      if (!state.allCategoriesLoaded) {
                        try {
                          categories = await notifier.ensureAllCategories();
                        } catch (_) {
                          categories = state.categories;
                        }
                      }
                      if (!mounted) return;
                      final pickedId = await showCatalogCategoryPicker(
                        context: context,
                        categories: categories,
                        selectedCategoryId: state.selectedCategoryId,
                      );
                      if (!mounted || pickedId == null) return;
                      await notifier.selectCategory(
                        pickedId.isEmpty ? null : pickedId,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        if (state.catalogPartial)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.tertiaryContainer
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        HebrewStrings.catalogPartialImportBanner,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (state.isLoadingResults)
          const LinearProgressIndicator(minHeight: 2),
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
        Expanded(child: _buildResults(state, notifier, draftQuantities)),
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
                        HebrewStrings.catalogMaterialsTitle,
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

    final scaffold = Scaffold(
      appBar: widget.appBar ??
          AppBar(
            title: const Text(HebrewStrings.catalogMaterialsTitle),
          ),
      body: SafeArea(child: body),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) return scaffold;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: scaffold,
          ),
        );
      },
    );
  }

  Widget _buildResults(
    CatalogSelectorState state,
    CatalogSelectorNotifier notifier,
    Map<String, int> draftQuantities,
  ) {
    if (state.availability != null && !state.catalogReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorMessage(
                message: HebrewStrings.catalogRealNotLoaded,
                onRetry: () => notifier.initialize(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                HebrewStrings.catalogRealNotLoadedHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                HebrewStrings.catalogSearchManualFallbackHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoadingResults && state.hits.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 6,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.hits.isEmpty) {
      return EmptyState(
        message: HebrewStrings.catalogSelectorEmpty,
        icon: Icons.search_off_outlined,
        hint: HebrewStrings.catalogSelectorEmptyHint,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Text(
                HebrewStrings.catalogProductsSection,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (state.loadedCount > 0)
                Text(
                  HebrewStrings.catalogResultsSummary(
                    state.loadedCount,
                    hasMore: state.hasMore,
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (!isWide) {
                return ListView.builder(
                  itemCount: state.hits.length,
                  itemBuilder: (context, index) =>
                      _productCard(state.hits[index], draftQuantities),
                );
              }
              final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : 2;
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: AppSpacing.xs,
                  crossAxisSpacing: AppSpacing.xs,
                  mainAxisExtent: 230,
                ),
                itemCount: state.hits.length,
                itemBuilder: (context, index) =>
                    _productCard(state.hits[index], draftQuantities),
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

  Widget _productCard(CatalogSearchHit hit, Map<String, int> draftQuantities) {
    return CatalogVariantResultCard(
      hit: hit,
      draftQuantity: draftQuantities[hit.variant.id] ?? 0,
      onOpenDetail: () => _handleOpenDetail(hit),
      onQuickAdd: () => _handleQuickAdd(hit),
    );
  }
}
