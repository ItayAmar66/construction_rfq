import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
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

    final isEmpty = count <= 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: isEmpty
            ? AppTheme.surfaceTint
            : AppTheme.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: isEmpty
            ? Border.all(color: AppTheme.borderColor)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10 : 11,
          color: isEmpty ? AppTheme.textSecondary : AppTheme.teal,
        ),
      ),
    );
  }
}
