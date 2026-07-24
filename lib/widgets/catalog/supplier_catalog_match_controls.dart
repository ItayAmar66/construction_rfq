import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Exact vs alternative match choice for catalog RFQ lines.
class SupplierCatalogMatchControls extends StatelessWidget {
  const SupplierCatalogMatchControls({
    super.key,
    required this.isExactMatch,
    required this.onExactMatchChanged,
    this.quotedName = '',
    this.quotedSku = '',
    this.onQuotedNameChanged,
    this.onQuotedSkuChanged,
    this.enabled = true,
  });

  final bool isExactMatch;
  final ValueChanged<bool> onExactMatchChanged;
  final String quotedName;
  final String quotedSku;
  final ValueChanged<String>? onQuotedNameChanged;
  final ValueChanged<String>? onQuotedSkuChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          HebrewStrings.supplierMatchChoiceTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // A two-option Wrap of ChoiceChips instead of a SegmentedButton: the
        // long Hebrew "exact match" label forces both segments wide and a
        // SegmentedButton neither shrinks nor wraps, so it overflowed the line
        // card on phones (≤ ~375px). Chips keep the single-choice semantics
        // and wrap to a second line when they can't fit.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(HebrewStrings.quoteExactMatch),
              selected: isExactMatch,
              onSelected: enabled
                  ? (selected) {
                      if (selected) onExactMatchChanged(true);
                    }
                  : null,
            ),
            ChoiceChip(
              avatar: const Icon(Icons.swap_horiz, size: 18),
              label: const Text(HebrewStrings.quoteAlternative),
              selected: !isExactMatch,
              onSelected: enabled
                  ? (selected) {
                      if (selected) onExactMatchChanged(false);
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isExactMatch
              ? HebrewStrings.supplierExactMatchHint
              : HebrewStrings.supplierAlternativeMatchHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        if (!isExactMatch) ...[
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: ValueKey('quoted-name-$quotedName-$isExactMatch'),
            initialValue: quotedName,
            decoration: const InputDecoration(
              labelText: HebrewStrings.quotedNameLabel,
              isDense: true,
            ),
            enabled: enabled,
            onChanged: onQuotedNameChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            key: ValueKey('quoted-sku-$quotedSku-$isExactMatch'),
            initialValue: quotedSku,
            decoration: const InputDecoration(
              labelText: HebrewStrings.quotedSkuLabel,
              isDense: true,
            ),
            enabled: enabled,
            onChanged: onQuotedSkuChanged,
          ),
        ],
      ],
    );
  }
}
