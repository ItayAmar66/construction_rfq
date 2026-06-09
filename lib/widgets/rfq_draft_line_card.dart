import 'package:flutter/material.dart';

import '../models/quote_request_item.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/hebrew_strings.dart';

class RfqDraftLineCard extends StatefulWidget {
  const RfqDraftLineCard({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onNotesChanged,
    this.lineNumber,
  });

  final QuoteRequestItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final ValueChanged<String>? onNotesChanged;
  final int? lineNumber;

  @override
  State<RfqDraftLineCard> createState() => _RfqDraftLineCardState();
}

class _RfqDraftLineCardState extends State<RfqDraftLineCard> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void didUpdateWidget(RfqDraftLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _notesController.text = widget.item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final metaParts = <String>[
      if (widget.lineNumber != null) '#${widget.lineNumber}',
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
                          style: const TextStyle(
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
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            if (widget.onNotesChanged != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: HebrewStrings.rfqLineNotesHint,
                  isDense: true,
                ),
                minLines: 2,
                maxLines: 3,
                onChanged: widget.onNotesChanged,
              ),
            ] else if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.notes!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Text(
                  HebrewStrings.quantity,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: item.quantity > 1
                      ? () => widget.onQuantityChanged(item.quantity - 1)
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
                  onPressed: () => widget.onQuantityChanged(item.quantity + 1),
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
