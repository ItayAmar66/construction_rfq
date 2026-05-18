import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/supplier_quote.dart';
import '../utils/app_spacing.dart';
import '../utils/app_theme.dart';
import '../utils/payment_terms.dart';

/// Read-only financial breakdown for a supplier quote.
class QuoteFinancialSummary extends StatelessWidget {
  const QuoteFinancialSummary({
    super.key,
    required this.quote,
    this.compact = false,
    this.isBestPrice = false,
    this.isFastestDelivery = false,
  });

  final SupplierQuote quote;
  final bool compact;
  final bool isBestPrice;
  final bool isFastestDelivery;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'he_IL', symbol: '₪');
    final dateFormat = DateFormat('dd/MM/yyyy', 'he');
    final hasVatLine = quote.vatAmount > 0 || quote.deliveryCost > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isBestPrice || isFastestDelivery)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.xxs,
              children: [
                if (isBestPrice) const _Badge(label: 'מחיר מינימלי'),
                if (isFastestDelivery) const _Badge(label: 'אספקה מהירה'),
              ],
            ),
          ),
        if (hasVatLine) ...[
          _Row(
            label: 'סכום ביניים',
            value: currency.format(quote.displaySubtotal),
            compact: compact,
          ),
          if (quote.deliveryCost > 0)
            _Row(
              label: 'משלוח',
              value: currency.format(quote.deliveryCost),
              compact: compact,
            ),
          _Row(
            label: 'מע״מ (${quote.vatRate.toStringAsFixed(0)}%)',
            value: currency.format(
              quote.vatAmount > 0
                  ? quote.vatAmount
                  : quote.displayTotal - quote.displaySubtotal,
            ),
            compact: compact,
          ),
          const Divider(height: 12),
        ],
        _Row(
          label: 'סה״כ כולל מע״מ',
          value: currency.format(quote.displayTotal),
          compact: compact,
          emphasized: true,
        ),
        const SizedBox(height: AppSpacing.xxs),
        _Row(
          label: 'תנאי תשלום',
          value: PaymentTerms.label(quote.paymentTerms),
          compact: compact,
        ),
        if (quote.validUntil != null)
          _Row(
            label: 'תוקף הצעה',
            value: dateFormat.format(quote.validUntil!),
            compact: compact,
          ),
        _Row(
          label: 'אספקה',
          value: quote.deliveryTime,
          compact: compact,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.compact,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textSecondary,
          fontSize: compact ? 11 : 12,
        );
    final valueStyle = emphasized
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            )
        : Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
            );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: compact ? 88 : 100, child: Text(label, style: labelStyle)),
          Expanded(child: Text(value, style: valueStyle)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.emerald,
        ),
      ),
    );
  }
}
