import '../../models/quote_request.dart';
import '../../models/supplier_quote.dart';

/// RFQ lifecycle notification events (no-op implementation in MVP).
enum RfqNotificationEventType {
  rfqSent,
  supplierQuoteReceived,
  quoteApproved,
  orderShipped,
}

class RfqNotificationPayload {
  const RfqNotificationPayload({
    required this.type,
    required this.requestId,
    this.quoteId,
    this.customerId,
    this.supplierId,
    this.title,
    this.body,
  });

  final RfqNotificationEventType type;
  final String requestId;
  final String? quoteId;
  final String? customerId;
  final String? supplierId;
  final String? title;
  final String? body;
}

abstract class RfqNotificationService {
  Future<void> notify(RfqNotificationPayload payload);

  Future<void> onRfqSent({
    required QuoteRequest request,
  }) =>
      notify(
        RfqNotificationPayload(
          type: RfqNotificationEventType.rfqSent,
          requestId: request.id,
          customerId: request.customerId,
          title: 'בקשה נשלחה לספקים',
          body: request.customerName,
        ),
      );

  Future<void> onSupplierQuoteReceived({
    required QuoteRequest request,
    required SupplierQuote quote,
  }) =>
      notify(
        RfqNotificationPayload(
          type: RfqNotificationEventType.supplierQuoteReceived,
          requestId: request.id,
          quoteId: quote.id,
          customerId: request.customerId,
          supplierId: quote.supplierId,
          title: 'התקבלה הצעת ספק',
          body: quote.supplierName,
        ),
      );

  Future<void> onQuoteApproved({
    required QuoteRequest request,
    required SupplierQuote quote,
  }) =>
      notify(
        RfqNotificationPayload(
          type: RfqNotificationEventType.quoteApproved,
          requestId: request.id,
          quoteId: quote.id,
          customerId: request.customerId,
          supplierId: quote.supplierId,
          title: 'הצעה אושרה',
          body: quote.supplierName,
        ),
      );

  Future<void> onOrderShipped({
    required QuoteRequest request,
    required SupplierQuote quote,
  }) =>
      notify(
        RfqNotificationPayload(
          type: RfqNotificationEventType.orderShipped,
          requestId: request.id,
          quoteId: quote.id,
          customerId: request.customerId,
          supplierId: quote.supplierId,
          title: 'הזמנה נשלחה',
          body: request.customerName,
        ),
      );
}

/// Default MVP — events are discarded unless recorded for tests.
class NoOpRfqNotificationService extends RfqNotificationService {
  NoOpRfqNotificationService();

  final List<RfqNotificationPayload> recorded = [];

  @override
  Future<void> notify(RfqNotificationPayload payload) async {
    recorded.add(payload);
  }
}
