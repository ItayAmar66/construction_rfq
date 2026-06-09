import 'package:flutter/material.dart';

import '../../models/catalog/catalog_search_hit.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/catalog_image_url.dart';
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
    final productTitle = hit.productName.isNotEmpty
        ? hit.productName
        : hit.displayLabel;
    final variantSubtitle = hit.productName.isNotEmpty &&
            variant.name.isNotEmpty &&
            variant.name != hit.displayLabel
        ? variant.name
        : null;
    final imagePath = CatalogImageUrl.resolveDisplayUrl(variant.image) ??
        (product != null ? CatalogImageUrl.resolveDisplayUrl(product.image) : null);
    final unitLabel = [
      if ((product?.unitType ?? '').isNotEmpty) product!.unitType,
      if (variant.sizeLabel.isNotEmpty) variant.sizeLabel,
      if ((product?.packagingLabel ?? '').isNotEmpty) product!.packagingLabel,
    ].where((s) => s.isNotEmpty).join(' · ');

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(imagePath: imagePath),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if ((product?.sku ?? '').isNotEmpty) ...[
                      _ProminentChip(
                        label: '${HebrewStrings.sku}: ${product!.sku}',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      productTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (variantSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        variantSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (hit.categoryBreadcrumb.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        hit.categoryBreadcrumb,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (unitLabel.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        unitLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.tonal(
                        onPressed: onSelect,
                        child: const Text(HebrewStrings.addRfqItem),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath != null && imagePath!.isNotEmpty
          ? Image.network(
              imagePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _Placeholder(),
            )
          : const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.textSecondary,
        size: 24,
      ),
    );
  }
}

class _ProminentChip extends StatelessWidget {
  const _ProminentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.teal,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
