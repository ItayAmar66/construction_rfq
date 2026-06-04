import 'package:flutter/material.dart';

import '../../models/catalog/catalog_search_hit.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';

class CatalogVariantResultCard extends StatelessWidget {
  const CatalogVariantResultCard({
    super.key,
    required this.hit,
    required this.onSelect,
  });

  final CatalogSearchHit hit;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final variant = hit.variant;
    final product = hit.product;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hit.displayLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (hit.categoryBreadcrumb.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hit.categoryBreadcrumb,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if ((product?.sku ?? '').isNotEmpty)
                    _Chip(label: '${HebrewStrings.sku}: ${product!.sku}'),
                  if ((product?.unitType ?? '').isNotEmpty)
                    _Chip(label: product!.unitType),
                  if (variant.sizeLabel.isNotEmpty)
                    _Chip(label: variant.sizeLabel),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonal(
                  onPressed: onSelect,
                  child: const Text(HebrewStrings.selectCatalogVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}
