import '../models/quote_request.dart';
import '../models/supplier_quote.dart';

/// Anonymous supplier labels during active tenders (customer view).
abstract final class TenderAnonymity {
  static String labelForQuote(
    SupplierQuote quote,
    List<SupplierQuote> allQuotes,
    QuoteRequest request,
  ) {
    if (!request.isTender || !request.isTenderActive) {
      return quote.supplierName;
    }
    final active = allQuotes
        .where((q) => q.supplierId.isNotEmpty)
        .map((q) => q.supplierId)
        .toSet()
        .toList()
      ..sort();
    final index = active.indexOf(quote.supplierId);
    if (index < 0) return 'ספק ${quote.supplierId.hashCode.abs() % 900 + 100}';
    return 'ספק ${_letter(index)}';
  }

  static String _letter(int index) {
    const letters = 'אבגדהוזחטיכלמנסעפצקרשת';
    if (index < letters.length) return letters[index];
    return '${letters[index % letters.length]}${index ~/ letters.length + 1}';
  }
}
