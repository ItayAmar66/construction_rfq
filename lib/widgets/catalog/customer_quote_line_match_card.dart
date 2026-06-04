import 'package:flutter/material.dart';

import '../../models/quote_request_item.dart';
import '../../models/supplier_quote_item.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/customer_quote_match_helpers.dart';
import '../../utils/hebrew_strings.dart';
import 'quote_request_catalog_snapshot.dart';
import 'supplier_quote_match_badge.dart';

/// Customer-facing line card for quote compare and approval detail screens.
class CustomerQuoteLineMatchCard extends StatelessWidget {
  const CustomerQuoteLineMatchCard({
    super.key,
    required this.quoteItem,
    this.requestLine,
    this.compact = false,
  });

  final SupplierQuoteItem quoteItem;
  final QuoteRequestItem? requestLine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!shouldShowCatalogMatchUi(quoteItem, requestLine)) {
      return compact ? _CompactManualLine(quoteItem: quoteItem) : _ManualLineCard(quoteItem: quoteItem);
    }
    return compact
        ? _CompactCatalogLine(quoteItem: quoteItem, requestLine: requestLine)
        : _FullCatalogLine(quoteItem: quoteItem, requestLine: requestLine);
  }
}

class _CompactManualLine extends StatelessWidget {
  const _CompactManualLine({required this.quoteItem});

  final SupplierQuoteItem quoteItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              quoteItem.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            '₪${quoteItem.totalItemPrice.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompactCatalogLine extends StatelessWidget {
  const _CompactCatalogLine({
    required this.quoteItem,
    required this.requestLine,
  });

  final SupplierQuoteItem quoteItem;
  final QuoteRequestItem? requestLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExact = quoteItem.isExactMatch;
    final isAlternative = quoteItem.isAlternative;
    final accent = isExact
        ? AppTheme.emerald
        : isAlternative
            ? AppTheme.amber
            : AppTheme.teal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isExact ? 0.06 : 0.05),
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (requestLine != null && requestLine!.isCatalogMatched)
              Text(
                '${HebrewStrings.requestedItemLabel}: ${requestLine!.productName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAlternative)
                        Text(
                          '${HebrewStrings.quotedItemLabel}: ${quoteItem.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          quoteItem.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (quoteItem.quotedSku != null &&
                          quoteItem.quotedSku!.isNotEmpty)
                        Text(
                          '${HebrewStrings.sku}: ${quoteItem.quotedSku}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      SupplierQuoteMatchBadge(
                        isExactMatch: isExact,
                        isAlternative: isAlternative,
                      ),
                      if (isAlternative &&
                          quoteItem.supplierNotes != null &&
                          quoteItem.supplierNotes!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            quoteItem.supplierNotes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₪${quoteItem.totalItemPrice.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualLineCard extends StatelessWidget {
  const _ManualLineCard({required this.quoteItem});

  final SupplierQuoteItem quoteItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quoteItem.displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _PricingRows(quoteItem: quoteItem),
            if (quoteItem.notes != null && quoteItem.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${HebrewStrings.notes}: ${quoteItem.notes}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullCatalogLine extends StatelessWidget {
  const _FullCatalogLine({
    required this.quoteItem,
    required this.requestLine,
  });

  final SupplierQuoteItem quoteItem;
  final QuoteRequestItem? requestLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExact = quoteItem.isExactMatch;
    final isAlternative = quoteItem.isAlternative;
    final accent = isExact
        ? AppTheme.emerald
        : isAlternative
            ? AppTheme.amber
            : AppTheme.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (requestLine != null && requestLine!.isCatalogMatched) ...[
                Text(
                  HebrewStrings.requestedCatalogItem,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                QuoteRequestCatalogSnapshot(item: requestLine!),
              ],
              Text(
                HebrewStrings.supplierQuotedItem,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isExact ? 0.08 : 0.06),
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            quoteItem.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SupplierQuoteMatchBadge(
                          isExactMatch: isExact,
                          isAlternative: isAlternative,
                        ),
                      ],
                    ),
                    if (quoteItem.quotedSku != null &&
                        quoteItem.quotedSku!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${HebrewStrings.sku}: ${quoteItem.quotedSku}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    if (isAlternative &&
                        quoteItem.supplierNotes != null &&
                        quoteItem.supplierNotes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${HebrewStrings.alternativeSupplierNotes}: '
                            '${quoteItem.supplierNotes}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.amber,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _PricingRows(quoteItem: quoteItem),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingRows extends StatelessWidget {
  const _PricingRows({required this.quoteItem});

  final SupplierQuoteItem quoteItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${HebrewStrings.quantity}: ${quoteItem.requestedQuantity}'),
        Text(
          '${HebrewStrings.unitPrice}: ₪${quoteItem.unitPrice.toStringAsFixed(2)}',
        ),
        Text(
          '${HebrewStrings.totalPrice}: ₪${quoteItem.totalItemPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
