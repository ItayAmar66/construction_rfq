import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text(HebrewStrings.quoteExactMatch),
            ),
            ButtonSegment(
              value: false,
              label: Text(HebrewStrings.quoteAlternative),
            ),
          ],
          selected: {isExactMatch},
          onSelectionChanged: enabled
              ? (selection) => onExactMatchChanged(selection.first)
              : null,
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
