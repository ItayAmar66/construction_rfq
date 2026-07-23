import 'package:flutter/material.dart';

import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';
import 'date_grouped_list.dart';
import 'design_system/search_field.dart';

/// A declarative filter tab for [FilterableListView].
///
/// [test] is a pure predicate over an already-loaded item — filtering happens
/// entirely client-side over data the caller has already fetched, so no
/// provider, query, or permission logic is touched.
class ListFilter<T> {
  const ListFilter({
    required this.label,
    required this.test,
    this.color,
  });

  /// The "show everything" tab — matches every item.
  factory ListFilter.all([String? label]) => ListFilter<T>(
        label: label ?? HebrewStrings.filterAll,
        test: (_) => true,
      );

  final String label;
  final bool Function(T item) test;
  final Color? color;
}

/// Presentation-only wrapper that adds an RTL-safe search field and a row of
/// status/segment filter pills above a [DateGroupedListView].
///
/// This widget owns no domain logic: it receives an already-loaded list plus
/// pure predicates ([ListFilter.test]) and a [searchTextFor] projection, and
/// only decides what subset of the caller's data to *display*. Firestore
/// queries, providers, and permission gating all remain the caller's concern.
class FilterableListView<T> extends StatefulWidget {
  const FilterableListView({
    super.key,
    required this.items,
    required this.dateFor,
    required this.itemBuilder,
    this.searchTextFor,
    this.filters = const [],
    this.searchHint,
    this.header,
    this.noResultsMessage,
    this.padding,
  });

  /// The full, already-loaded list. The caller is responsible for showing its
  /// own "no data at all" empty state before reaching this widget.
  final List<T> items;
  final DateTime Function(T item) dateFor;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Concatenated searchable text for an item (name, number, project, …).
  /// When null the search field is hidden and only the filter tabs show.
  final String Function(T item)? searchTextFor;

  /// Optional segment tabs. When empty, only the search field is shown.
  final List<ListFilter<T>> filters;

  final String? searchHint;

  /// Optional widget rendered above the search/filter bar (e.g. an intro card).
  final Widget? header;

  final String? noResultsMessage;
  final EdgeInsets? padding;

  @override
  State<FilterableListView<T>> createState() => _FilterableListViewState<T>();
}

class _FilterableListViewState<T> extends State<FilterableListView<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _activeFilter = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FilterableListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the active tab in range if the caller's filter set shrinks.
    if (_activeFilter >= widget.filters.length && widget.filters.isNotEmpty) {
      _activeFilter = 0;
    }
  }

  List<T> get _searched {
    final projector = widget.searchTextFor;
    final q = _query.trim().toLowerCase();
    if (projector == null || q.isEmpty) return widget.items;
    return widget.items
        .where((it) => projector(it).toLowerCase().contains(q))
        .toList();
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _searchController.clear();
      _activeFilter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searched;
    final hasFilters = widget.filters.isNotEmpty;
    final activeFilter =
        hasFilters ? widget.filters[_activeFilter] : ListFilter<T>.all();
    final filtered =
        hasFilters ? searched.where(activeFilter.test).toList() : searched;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        if (widget.searchTextFor != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: SearchField(
              controller: _searchController,
              hintText: widget.searchHint ?? HebrewStrings.searchListHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        if (hasFilters)
          _FilterBar<T>(
            filters: widget.filters,
            activeIndex: _activeFilter,
            countFor: (f) => searched.where(f.test).length,
            onSelected: (i) => setState(() => _activeFilter = i),
          ),
        Expanded(
          child: filtered.isEmpty
              ? _NoResults(
                  message: widget.noResultsMessage ??
                      HebrewStrings.noMatchingResults,
                  onClear: _resetFilters,
                )
              : DateGroupedListView<T>(
                  items: filtered,
                  dateFor: widget.dateFor,
                  itemBuilder: widget.itemBuilder,
                  padding: widget.padding ??
                      const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                ),
        ),
      ],
    );
  }
}

class _FilterBar<T> extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.activeIndex,
    required this.countFor,
    required this.onSelected,
  });

  final List<ListFilter<T>> filters;
  final int activeIndex;
  final int Function(ListFilter<T> filter) countFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return _FilterPill(
            label: filter.label,
            count: countFor(filter),
            selected: index == activeIndex,
            accent: filter.color ?? AppTheme.navy,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? accent : Colors.white;
    final fg = selected ? Colors.white : AppTheme.textSecondary;
    final borderColor = selected ? accent : AppTheme.borderColor;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppTheme.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.message, required this.onClear});

  final String message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_outlined,
                size: 26,
                color: AppTheme.navy.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text(HebrewStrings.clearFilters),
            ),
          ],
        ),
      ),
    );
  }
}
