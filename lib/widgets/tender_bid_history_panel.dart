import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/supplier_quote.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/tender_anonymity.dart';
import '../models/quote_request.dart';

/// Chronological tender bid versions (newest first).
class TenderBidHistoryPanel extends StatelessWidget {
  const TenderBidHistoryPanel({
    super.key,
    required this.quotes,
    required this.request,
    this.forSupplierView = false,
    this.currentSupplierId,
  });

  final List<SupplierQuote> quotes;
  final QuoteRequest request;
  final bool forSupplierView;
  final String? currentSupplierId;

  @override
  Widget build(BuildContext context) {
    final tenderQuotes = quotes
        .where(
          (q) =>
              q.isTenderBid,
        )
        .toList()
      ..sort((a, b) {
        final byVersion = b.bidVersion.compareTo(a.bidVersion);
        if (byVersion != 0) return byVersion;
        return b.createdAt.compareTo(a.createdAt);
      });

    if (tenderQuotes.isEmpty) {
      return const SizedBox.shrink();
    }

    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final dateFmt = DateFormat('dd/MM HH:mm', 'he');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'היסטוריית הצעות',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...tenderQuotes.take(8).map((q) {
            final label = forSupplierView && q.supplierId == currentSupplierId
                ? 'ההצעה שלך'
                : TenderAnonymity.labelForQuote(q, quotes, request);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'v${q.bidVersion}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          dateFmt.format(q.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currency.format(q.displayTotal),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
