import 'package:flutter/material.dart';

import '../models/quote_request_item.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';

class RfqDraftLineCard extends StatelessWidget {
  const RfqDraftLineCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onNotesChanged,
  });

  final QuoteRequestItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final ValueChanged<String>? onNotesChanged;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      if (item.sku != null && item.sku!.isNotEmpty) '${HebrewStrings.sku}: ${item.sku}',
      if (item.category.isNotEmpty) item.category,
      if (item.unitType.isNotEmpty) item.unitType,
      if (item.packagingLabel != null && item.packagingLabel!.isNotEmpty)
        item.packagingLabel!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          metaParts.join(' · '),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.isCatalogMatched)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.sm,
                    ),
                    child: Chip(
                      label: Text(
                        HebrewStrings.catalogMatchedBadge,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            if (item.notes != null && item.notes!.isNotEmpty && onNotesChanged == null) ...[
              const SizedBox(height: 4),
              Text(
                item.notes!,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            if (onNotesChanged != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: ValueKey('notes-${item.id}'),
                initialValue: item.notes ?? '',
                decoration: const InputDecoration(
                  labelText: HebrewStrings.rfqLineNotesHint,
                  isDense: true,
                ),
                maxLines: 2,
                onChanged: onNotesChanged,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  HebrewStrings.quantity,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: item.quantity > 1
                      ? () => onQuantityChanged(item.quantity - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => onQuantityChanged(item.quantity + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
