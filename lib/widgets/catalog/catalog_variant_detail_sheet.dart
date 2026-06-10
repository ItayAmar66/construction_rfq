import 'package:flutter/material.dart';

import '../../models/catalog/catalog_rfq_line_draft.dart';
import '../../models/catalog/catalog_search_hit.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/catalog_image_url.dart';
import '../../utils/hebrew_strings.dart';

/// Product detail bottom sheet: image, info, quantity, notes, add to RFQ.
class CatalogVariantDetailSheet {
  CatalogVariantDetailSheet._();

  static Future<CatalogRfqLineDraft?> show(
    BuildContext context, {
    required CatalogSearchHit hit,
  }) {
    return showModalBottomSheet<CatalogRfqLineDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CatalogVariantDetailBody(hit: hit),
    );
  }
}

class _CatalogVariantDetailBody extends StatefulWidget {
  const _CatalogVariantDetailBody({required this.hit});

  final CatalogSearchHit hit;

  @override
  State<_CatalogVariantDetailBody> createState() =>
      _CatalogVariantDetailBodyState();
}

class _CatalogVariantDetailBodyState extends State<_CatalogVariantDetailBody> {
  int _quantity = 1;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final base = CatalogRfqLineDraft.fromSearchHit(widget.hit);
    Navigator.of(context).pop(
      CatalogRfqLineDraft(
        variantId: base.variantId,
        productId: base.productId,
        categoryId: base.categoryId,
        categoryPath: base.categoryPath,
        displayName: base.displayName,
        productName: base.productName,
        variantName: base.variantName,
        sku: base.sku,
        unitType: base.unitType,
        packagingLabel: base.packagingLabel,
        imagePath: base.imagePath,
        attributesSnapshot: base.attributesSnapshot,
        sourceCatalogVersion: base.sourceCatalogVersion,
        quantity: _quantity,
        notes: _notesController.text.trim(),
        isCatalogMatched: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hit = widget.hit;
    final variant = hit.variant;
    final product = hit.product;
    final theme = Theme.of(context);
    final imageUrl = CatalogImageUrl.resolveDisplayUrl(variant.image) ??
        (product != null ? CatalogImageUrl.resolveDisplayUrl(product.image) : null);

    final title = hit.productName.isNotEmpty ? hit.productName : hit.displayLabel;
    final unitParts = <String>[
      if ((product?.unitType ?? '').isNotEmpty) product!.unitType,
      if (variant.sizeLabel.isNotEmpty) variant.sizeLabel,
      if ((product?.packagingLabel ?? '').isNotEmpty) product!.packagingLabel,
    ];

    final description = (product?.descriptionPlain ?? '').trim();
    final specs = product?.specs.entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .toList() ??
        const <String>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                HebrewStrings.catalogProductDetails,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: AspectRatio(
                          aspectRatio: 1.2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceTint,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const _ImagePlaceholder(),
                                    )
                                  : const _ImagePlaceholder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (variant.name.isNotEmpty &&
                        variant.name != hit.displayLabel) ...[
                      const SizedBox(height: 4),
                      Text(
                        variant.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (hit.categoryBreadcrumb.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        hit.categoryBreadcrumb,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if ((product?.sku ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${HebrewStrings.sku}: ${product!.sku}',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                    if (unitParts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(unitParts.join(' · ')),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        HebrewStrings.description,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(description),
                    ] else if (specs.isEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        HebrewStrings.catalogNoDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (specs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ...specs.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: HebrewStrings.rfqLineNotesHint,
                      ),
                      minLines: 2,
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Text(HebrewStrings.quantity),
                        const Spacer(),
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_quantity',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: _submit,
                child: const Text(HebrewStrings.addRfqItem),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 64,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
