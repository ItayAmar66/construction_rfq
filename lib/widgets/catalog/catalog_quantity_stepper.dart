import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Inline +/- quantity control for catalog product rows.
class CatalogQuantityStepper extends StatelessWidget {
  const CatalogQuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (quantity <= 0) {
      return IconButton.filledTonal(
        onPressed: onIncrement,
        tooltip: HebrewStrings.addRfqItem,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
          foregroundColor: AppTheme.teal,
        ),
        icon: const Icon(Icons.add, size: 22),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        color: AppTheme.surfaceTint,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: HebrewStrings.decreaseQuantity,
            onPressed: onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '$quantity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: HebrewStrings.increaseQuantity,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: AppTheme.teal),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.teal,
        minimumSize: const Size(36, 36),
      ),
    );
  }
}
