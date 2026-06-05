import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/supplier_quote.dart';
import '../models/supplier_quote_item.dart';
import '../utils/customer_quote_match_helpers.dart';
import '../utils/supplier_quote_status.dart';

/// Validates customer quote approval rules (no I/O).
abstract final class ApprovalService {
  static void validateApproval({
    required QuoteRequest request,
    required SupplierQuote quote,
    required String customerId,
  }) {
    if (request.customerId != customerId) {
      throw Exception('אין הרשאה לאשר הצעה זו');
    }
    if (request.hasApprovedQuote && request.approvedQuoteId != quote.id) {
      throw Exception('כבר אושרה הצעה אחרת לבקשה זו');
    }
    if (quote.quoteRequestId != request.id) {
      throw Exception('ההצעה אינה שייכת לבקשה זו');
    }
    if (request.status.isLocked &&
        !(request.status == QuoteRequestStatus.ordered &&
            request.approvedQuoteId == quote.id)) {
      throw Exception('לא ניתן לאשר הצעה לבקשה בסטטוס זה');
    }
    if (quote.status != SupplierQuoteStatus.sent &&
        quote.status != SupplierQuoteStatus.approved) {
      throw Exception('לא ניתן לאשר הצעה בסטטוס זה');
    }
  }

  static bool hasAlternativeLines(List<SupplierQuoteItem> items) {
    return quoteHasAlternativeItems(items);
  }

  static int alternativeLineCount(List<SupplierQuoteItem> items) {
    return alternativeItemCount(items);
  }

  static String alternativeWarningMessage(List<SupplierQuoteItem> items) {
    final count = alternativeLineCount(items);
    if (count == 0) return '';
    return count == 1
        ? 'ההצעה כוללת פריט חלופי אחד — ודא שהחלופה מתאימה לפרויקט'
        : 'ההצעה כוללת $count פריטי חלופה — ודא שהחלופות מתאימות לפרויקט';
  }
}
