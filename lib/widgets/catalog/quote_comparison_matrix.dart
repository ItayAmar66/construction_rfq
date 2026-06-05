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
                          _HeaderCell(
                            '₪${quote.displayTotal.toStringAsFixed(0)}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
    final statusColor = switch (cell.status) {
      QuoteMatrixCellStatus.exact => AppTheme.teal,
      QuoteMatrixCellStatus.alternative => AppTheme.amber,
      QuoteMatrixCellStatus.manual => AppTheme.navy,
      QuoteMatrixCellStatus.missing => AppTheme.textSecondary,
    };

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
          const SizedBox(height: 2),
          Text(
            matrixStatusLabel(cell.status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
