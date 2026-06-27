import '../models/quote_request.dart';
import '../models/quote_status.dart';
import '../models/receipt_status.dart';
import '../models/request_audit_event.dart';
import '../models/supplier_quote.dart';
import '../utils/supplier_quote_status.dart';

/// Builds ordered lifecycle events aligned with [RequestTimeline] steps.
abstract final class RequestAuditTrail {
  static List<RequestAuditEvent> build({
    required QuoteRequest request,
    List<SupplierQuote> quotes = const [],
  }) {
    final events = <RequestAuditEvent>[
      RequestAuditEvent(
        type: RequestAuditEventType.draftCreated,
        at: request.createdAt,
        label: 'טיוטה נוצרה',
      ),
    ];

    if (request.status != QuoteRequestStatus.draft &&
        request.status != QuoteRequestStatus.cancelled) {
      events.add(
        RequestAuditEvent(
          type: RequestAuditEventType.sent,
          at: request.createdAt,
          label: 'נשלח לספקים',
        ),
      );
    }

    final visibleQuotes = quotes
        .where((q) => SupplierQuoteStatus.isVisibleToCustomer(q.status))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final quote in visibleQuotes) {
      events.add(
        RequestAuditEvent(
          type: RequestAuditEventType.supplierQuoted,
          at: quote.createdAt,
          label: 'ספק הגיש הצעה',
          detail: quote.supplierName,
        ),
      );
    }

    final statusAt = request.updatedAt ?? request.createdAt;

    if (request.approvedQuoteId != null &&
        (request.status == QuoteRequestStatus.ordered ||
            request.status == QuoteRequestStatus.shipped ||
            request.status == QuoteRequestStatus.pendingReceipt ||
            request.status == QuoteRequestStatus.receivedFull ||
            request.status == QuoteRequestStatus.receivedWithIssues ||
            request.status == QuoteRequestStatus.completed)) {
      events.add(
        RequestAuditEvent(
          type: RequestAuditEventType.quoteApproved,
          at: statusAt,
          label: 'הצעה אושרה',
        ),
      );
    }

    if (request.status == QuoteRequestStatus.shipped ||
        request.status == QuoteRequestStatus.pendingReceipt ||
        request.status == QuoteRequestStatus.receivedFull ||
        request.status == QuoteRequestStatus.receivedWithIssues ||
        request.status == QuoteRequestStatus.completed) {
      events.add(
        RequestAuditEvent(
          type: RequestAuditEventType.shipped,
          at: request.shippedAt ?? statusAt,
          label: request.status == QuoteRequestStatus.pendingReceipt
              ? 'ממתין לאישור קבלה'
              : request.receiptStatus == ReceiptStatus.receivedFull
                  ? 'התקבל במלואו'
                  : request.receiptStatus == ReceiptStatus.receivedWithIssues
                      ? 'התקבל עם חריגות'
                      : 'בדרך',
        ),
      );
    }

    events.sort((a, b) => a.at.compareTo(b.at));
    return events;
  }

  static String labelFor(RequestAuditEventType type) {
    switch (type) {
      case RequestAuditEventType.draftCreated:
        return 'טיוטה נוצרה';
      case RequestAuditEventType.sent:
        return 'נשלח לספקים';
      case RequestAuditEventType.supplierQuoted:
        return 'ספק הגיש הצעה';
      case RequestAuditEventType.quoteApproved:
        return 'הצעה אושרה';
      case RequestAuditEventType.shipped:
        return 'בדרך';
    }
  }
}
