import 'package:flutter/material.dart';

import '../../models/quote_request_item.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

/// Catalog snapshot header for supplier quote/tender line forms.
class QuoteRequestCatalogSnapshot extends StatelessWidget {
  const QuoteRequestCatalogSnapshot({super.key, required this.item});

  final QuoteRequestItem item;

  @override
  Widget build(BuildContext context) {
    if (!item.isCatalogMatched) return const SizedBox.shrink();

    final metaParts = <String>[
      if (item.sku != null && item.sku!.isNotEmpty)
        '${HebrewStrings.sku}: ${item.sku}',
      if (item.category.isNotEmpty) item.category,
      if (item.unitType.isNotEmpty) item.unitType,
      if (item.packagingLabel != null && item.packagingLabel!.isNotEmpty)
        item.packagingLabel!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppTheme.teal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    HebrewStrings.catalogMatchedBadge,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.productName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (metaParts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                metaParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
