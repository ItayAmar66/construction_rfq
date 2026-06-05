import '../models/quote_request_item.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';

/// Per-cell match status in the quote comparison matrix.
enum QuoteMatrixCellStatus {
  exact,
  alternative,
  manual,
  missing,
}

class QuoteMatrixCell {
  const QuoteMatrixCell({
    this.unitPrice,
    this.lineTotal,
    this.status = QuoteMatrixCellStatus.missing,
  });

  final double? unitPrice;
  final double? lineTotal;
  final QuoteMatrixCellStatus status;

  bool get hasPrice => unitPrice != null && unitPrice! > 0;
}

class QuoteComparisonMatrixData {
  const QuoteComparisonMatrixData({
    required this.rows,
    required this.columns,
    required this.cells,
  });

  final List<QuoteRequestItem> rows;
  final List<SupplierQuote> columns;

  /// `cells[quoteId][requestItemId]`
  final Map<String, Map<String, QuoteMatrixCell>> cells;

  int get rowCount => rows.length;
  int get columnCount => columns.length;
}

QuoteMatrixCellStatus _statusForLine({
  required SupplierQuoteItem? quoteItem,
  required QuoteRequestItem requestItem,
}) {
  if (quoteItem == null || quoteItem.unitPrice <= 0) {
    return QuoteMatrixCellStatus.missing;
  }
  if (requestItem.isCatalogMatched) {
    if (quoteItem.isExactMatch) return QuoteMatrixCellStatus.exact;
    if (quoteItem.isAlternative) return QuoteMatrixCellStatus.alternative;
  }
  if (!quoteItem.isExactMatch && !quoteItem.isAlternative) {
    return QuoteMatrixCellStatus.manual;
  }
  return QuoteMatrixCellStatus.manual;
}

QuoteComparisonMatrixData buildQuoteComparisonMatrix({
  required List<QuoteRequestItem> requestItems,
  required List<SupplierQuote> quotes,
}) {
  final activeQuotes = quotes
      .where((q) => q.items.isNotEmpty || q.displayTotal > 0)
      .toList();

  final cells = <String, Map<String, QuoteMatrixCell>>{};
  for (final quote in activeQuotes) {
    final rowCells = <String, QuoteMatrixCell>{};

    for (final requestItem in requestItems) {
      SupplierQuoteItem? matched;
      for (final qi in quote.items) {
        if (qi.requestItemId == requestItem.id) {
          matched = qi;
          break;
        }
      }

      rowCells[requestItem.id] = QuoteMatrixCell(
        unitPrice: matched?.unitPrice,
        lineTotal: matched?.totalItemPrice,
        status: _statusForLine(
          quoteItem: matched,
          requestItem: requestItem,
        ),
      );
    }
    cells[quote.id] = rowCells;
  }

  return QuoteComparisonMatrixData(
    rows: requestItems,
    columns: activeQuotes,
    cells: cells,
  );
}

String matrixStatusLabel(QuoteMatrixCellStatus status) {
  switch (status) {
    case QuoteMatrixCellStatus.exact:
      return 'מדויק';
    case QuoteMatrixCellStatus.alternative:
      return 'חלופה';
    case QuoteMatrixCellStatus.manual:
      return 'ידני';
    case QuoteMatrixCellStatus.missing:
      return 'חסר';
  }
}
