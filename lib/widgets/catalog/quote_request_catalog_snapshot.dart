import 'package:flutter/material.dart';

import '../../models/quote_request_item.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Compact catalog metadata for supplier quote/tender line forms.
class QuoteRequestCatalogSnapshot extends StatelessWidget {
  const QuoteRequestCatalogSnapshot({
    super.key,
    required this.item,
    this.lineNumber,
  });

  final QuoteRequestItem item;
  final int? lineNumber;

  @override
  Widget build(BuildContext context) {
    if (!item.isCatalogMatched) return const SizedBox.shrink();

    final metaParts = <String>[
      if (lineNumber != null) 'שורה $lineNumber',
      if (item.sku != null && item.sku!.isNotEmpty)
        '${HebrewStrings.sku}: ${item.sku}',
      if (item.category.isNotEmpty) item.category,
      if (item.unitType.isNotEmpty) item.unitType,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.teal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Chip(
              label: Text(
                HebrewStrings.catalogMatchedBadge,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                metaParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
