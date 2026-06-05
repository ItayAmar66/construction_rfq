import 'package:flutter/material.dart';

import '../../models/quote_request.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/quote_comparison_matrix.dart';
import '../../utils/tender_anonymity.dart';

/// Desktop-friendly RFQ line × supplier quote matrix.
class QuoteComparisonMatrix extends StatelessWidget {
  const QuoteComparisonMatrix({
    super.key,
    required this.data,
    required this.request,
    this.minTableWidth = 640,
  });

  final QuoteComparisonMatrixData data;
  final QuoteRequest request;
  final double minTableWidth;

  @override
  Widget build(BuildContext context) {
    if (data.rowCount == 0 || data.columnCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final hideIdentity = request.isTender && request.isTenderActive;
    final columnSummaries = buildMatrixColumnSummaries(data);
    final lowestTotal = columnSummaries
        .map((s) => s.quotedTotal)
        .where((value) => value > 0)
        .fold<double?>(
          null,
          (min, value) => min == null || value < min ? value : min,
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'מטריצת השוואה',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.6),
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTint,
                      ),
                      children: [
                        const _HeaderCell('פריט'),
                        for (final quote in data.columns)
                          _HeaderCell(
                            hideIdentity
                                ? TenderAnonymity.labelForQuote(
                                    quote,
                                    data.columns,
                                    request,
                                  )
                                : _shortName(quote.supplierName),
                          ),
                      ],
                    ),
                    for (final row in data.rows)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              row.productName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          for (final quote in data.columns)
                            _MatrixCellView(
                              cell: data.cells[quote.id]?[row.id] ??
                                  const QuoteMatrixCell(),
                            ),
                        ],
                      ),
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withValues(alpha: 0.04),
                      ),
                      children: [
                        const _HeaderCell('סה״כ'),
                        for (final quote in data.columns)
                          _TotalCell(
                            total: quote.displayTotal,
                            isLowest: lowestTotal != null &&
                                quote.displayTotal == lowestTotal,
                          ),
                      ],
                    ),
                    TableRow(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceTint.withValues(alpha: 0.5),
                      ),
                      children: [
                        const _HeaderCell('התאמות'),
                        for (final summary in columnSummaries)
                          _HeaderCell(summary.statusBreakdown),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (columnSummaries.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < data.columns.length; i++)
                    _QuoteDecisionChip(
                      label: hideIdentity
                          ? TenderAnonymity.labelForQuote(
                              data.columns[i],
                              data.columns,
                              request,
                            )
                          : _shortName(data.columns[i].supplierName),
                      summary: columnSummaries[i],
                      isLowest: lowestTotal != null &&
                          columnSummaries[i].quotedTotal == lowestTotal,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _shortName(String name) {
    if (name.length <= 14) return name;
    return '${name.substring(0, 12)}…';
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MatrixCellView extends StatelessWidget {
  const _MatrixCellView({required this.cell});

  final QuoteMatrixCell cell;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(cell.status);
    final statusIcon = _statusIcon(cell.status);

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cell.hasPrice ? '₪${cell.unitPrice!.toStringAsFixed(0)}' : '—',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 3),
              Text(
                matrixStatusLabel(cell.status),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _statusColor(QuoteMatrixCellStatus status) {
  return switch (status) {
    QuoteMatrixCellStatus.exact => AppTheme.teal,
    QuoteMatrixCellStatus.alternative => AppTheme.amber,
    QuoteMatrixCellStatus.manual => AppTheme.navy,
    QuoteMatrixCellStatus.missing => AppTheme.textSecondary,
  };
}

IconData _statusIcon(QuoteMatrixCellStatus status) {
  return switch (status) {
    QuoteMatrixCellStatus.exact => Icons.check_circle_outline,
    QuoteMatrixCellStatus.alternative => Icons.swap_horiz,
    QuoteMatrixCellStatus.manual => Icons.edit_outlined,
    QuoteMatrixCellStatus.missing => Icons.remove_circle_outline,
  };
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.total,
    required this.isLowest,
  });

  final double total;
  final bool isLowest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            '₪${total.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isLowest ? AppTheme.teal : null,
                ),
            textAlign: TextAlign.center,
          ),
          if (isLowest)
            Text(
              'הנמוך ביותר',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.teal,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _QuoteDecisionChip extends StatelessWidget {
  const _QuoteDecisionChip({
    required this.label,
    required this.summary,
    required this.isLowest,
  });

  final String label;
  final QuoteMatrixColumnSummary summary;
  final bool isLowest;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isLowest ? Icons.emoji_events_outlined : Icons.receipt_long_outlined,
        size: 16,
        color: isLowest ? AppTheme.teal : AppTheme.navy,
      ),
      label: Text('$label · ${summary.statusBreakdown}'),
      visualDensity: VisualDensity.compact,
    );
  }
}
