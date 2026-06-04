import 'package:flutter/material.dart';

import '../../models/supplier_quote.dart';
import '../../models/supplier_quote_item.dart';
import '../../utils/app_theme.dart';
import '../../utils/customer_quote_match_helpers.dart';
import '../../utils/hebrew_strings.dart';

/// Confirmation dialog before customer approves a supplier quote.
class CustomerQuoteApprovalDialog {
  CustomerQuoteApprovalDialog._();

  static Future<bool?> show({
    required BuildContext context,
    required SupplierQuote quote,
    required List<SupplierQuoteItem> items,
  }) {
    final altCount = alternativeItemCount(items);
    final hasAlternatives = altCount > 0;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('אישור הצעה'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasAlternatives) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        HebrewStrings.alternativeApprovalWarning(altCount),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'לאשר את הצעת ${quote.supplierName} בסך '
              '₪${quote.displayTotal.toStringAsFixed(0)}?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(HebrewStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(HebrewStrings.yes),
          ),
        ],
      ),
    );
  }
}
