import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/hebrew_strings.dart';
import '../../utils/quote_decision_metrics.dart';

class QuoteComparisonDecisionSummary extends StatelessWidget {
  const QuoteComparisonDecisionSummary({
    super.key,
    required this.metrics,
    this.supplierName,
  });

  final QuoteDecisionMetrics metrics;
  final String? supplierName;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            supplierName != null
                ? 'סיכום החלטה — $supplierName'
                : 'סיכום השוואה',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetricChip(
                label: 'סה״כ',
                value: '₪${metrics.totalPrice.toStringAsFixed(0)}',
              ),
              if (metrics.exactCount > 0)
                _MetricChip(
                  label: HebrewStrings.exactMatchBadge,
                  value: '${metrics.exactCount}',
                ),
              if (metrics.alternativeCount > 0)
                _MetricChip(
                  label: HebrewStrings.alternativeMatchBadge,
                  value: '${metrics.alternativeCount}',
                ),
              if (metrics.manualCount > 0)
                _MetricChip(label: 'ידני', value: '${metrics.manualCount}'),
              if (metrics.emptyQuotedLines > 0)
                _MetricChip(
                  label: 'שורות חסרות',
                  value: '${metrics.emptyQuotedLines}',
                  warn: true,
                ),
            ],
          ),
          if (metrics.deliveryTime.isNotEmpty ||
              metrics.validUntil != null ||
              metrics.paymentTerms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            if (metrics.deliveryTime.isNotEmpty)
              Text('אספקה: ${metrics.deliveryTime}'),
            if (metrics.validUntil != null)
              Text('תוקף: ${dateFormat.format(metrics.validUntil!)}'),
            if (metrics.paymentTerms.isNotEmpty)
              Text('תנאי תשלום: ${metrics.paymentTerms}'),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppTheme.amber : AppTheme.teal;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
