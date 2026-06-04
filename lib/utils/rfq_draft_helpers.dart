import '../models/quote_request_item.dart';

/// Summary counts for RFQ draft builder UI.
class RfqDraftSummary {
  const RfqDraftSummary({
    required this.totalLines,
    required this.catalogLines,
    required this.manualLines,
    required this.linesMissingNotes,
    required this.totalQuantity,
  });

  final int totalLines;
  final int catalogLines;
  final int manualLines;
  final int linesMissingNotes;
  final int totalQuantity;

  bool get hasLines => totalLines > 0;
}

RfqDraftSummary summarizeRfqDraft(List<QuoteRequestItem> items) {
  var catalog = 0;
  var manual = 0;
  var missingNotes = 0;
  var quantity = 0;

  for (final item in items) {
    quantity += item.quantity;
    if (item.isCatalogMatched) {
      catalog++;
    } else {
      manual++;
    }
    if (item.notes == null || item.notes!.trim().isEmpty) {
      missingNotes++;
    }
  }

  return RfqDraftSummary(
    totalLines: items.length,
    catalogLines: catalog,
    manualLines: manual,
    linesMissingNotes: missingNotes,
    totalQuantity: quantity,
  );
}
