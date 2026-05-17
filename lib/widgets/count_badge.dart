import 'package:flutter/material.dart';

import '../utils/count_badge.dart';

/// Compact numeric badge for RTL layouts (request cards, app bars).
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.showEmptyLabel = false,
    this.compact = false,
  });

  final int count;
  final bool showEmptyLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = countBadgeLabel(count, showEmptyLabel: showEmptyLabel);
    if (label == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isEmpty = count <= 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.grey.shade300
            : theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: compact ? 11 : 12,
          color: isEmpty ? Colors.grey.shade700 : null,
        ),
      ),
    );
  }
}
