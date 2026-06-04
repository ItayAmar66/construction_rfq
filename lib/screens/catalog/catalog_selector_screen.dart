import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../providers/catalog_selector_provider.dart';
import '../../utils/app_spacing.dart';
import '../../utils/hebrew_strings.dart';
import '../../widgets/catalog/catalog_variant_result_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/loading_view.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSelect(CatalogRfqLineDraft draft) {
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
            onChanged: (value) {
              if (value.isEmpty) notifier.setSearchText('');
            },
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
        const SizedBox(height: AppSpacing.sm),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ErrorMessage(message: state.errorMessage!),
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

  Widget _buildResults(CatalogSelectorState state, CatalogSelectorNotifier notifier) {
    if (state.isLoadingResults) {
      return const LoadingView();
    }

    if (!state.hasActiveQuery) {
      return const EmptyState(
        message: HebrewStrings.catalogSelectorPrompt,
        icon: Icons.manage_search_outlined,
        hint: HebrewStrings.catalogSelectorPromptHint,
      );
    }

    if (state.hits.isEmpty) {
      return const EmptyState(
        message: HebrewStrings.catalogSelectorEmpty,
        icon: Icons.search_off_outlined,
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
