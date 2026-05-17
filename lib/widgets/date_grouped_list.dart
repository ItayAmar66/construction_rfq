import 'package:flutter/material.dart';

import '../utils/date_grouping.dart';

/// Scrollable list with Hebrew date section headers (RTL-friendly).
class DateGroupedListView<T> extends StatelessWidget {
  const DateGroupedListView({
    super.key,
    required this.items,
    required this.dateFor,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.separatorBetweenItems = 8,
    this.separatorAfterHeader = 8,
    this.separatorBetweenSections = 16,
  });

  final List<T> items;
  final DateTime Function(T item) dateFor;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsets padding;
  final double separatorBetweenItems;
  final double separatorAfterHeader;
  final double separatorBetweenSections;

  @override
  Widget build(BuildContext context) {
    final groups = groupItemsByDate(items, dateFor);
    final entries = _buildEntries(groups);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: padding,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final position = entries[index];
        if (position.isHeader) {
          final isFirst = index == 0;
          return Padding(
            padding: EdgeInsets.only(
              top: isFirst ? 0 : separatorBetweenSections,
              bottom: separatorAfterHeader,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                position.header!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: separatorBetweenItems),
          child: itemBuilder(context, position.item as T),
        );
      },
    );
  }

  List<_ListPosition<T>> _buildEntries(List<DateGroupSection<T>> groups) {
    final entries = <_ListPosition<T>>[];
    for (final group in groups) {
      entries.add(_ListPosition.header(group.header));
      for (final item in group.items) {
        entries.add(_ListPosition.item(item));
      }
    }
    return entries;
  }
}

class _ListPosition<T> {
  _ListPosition.header(this.header) : item = null;
  _ListPosition.item(this.item) : header = null;

  final String? header;
  final T? item;

  bool get isHeader => header != null;
}
