import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/services/notifications/rfq_notification_service.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoOpRfqNotificationService records payloads', () async {
    final service = NoOpRfqNotificationService();
    final request = QuoteRequest(
      id: 'req',
      customerId: 'c1',
      customerName: 'Co',
      customerPhone: '050',
      customerCity: 'TLV',
      customerType: 'commercial',
      status: QuoteRequestStatus.sent,
      createdAt: DateTime(2024),
    );
    final quote = SupplierQuote(
      id: 'q1',
      quoteRequestId: 'req',
      supplierId: 's1',
      supplierName: 'Supplier',
      supplierType: 'commercial',
      deliveryTime: '2d',
      totalPrice: 10,
      status: SupplierQuoteStatus.sent,
      createdAt: DateTime(2024),
      items: const [],
    );

    await service.onRfqSent(request: request);
    await service.onSupplierQuoteReceived(request: request, quote: quote);

    expect(service.recorded, hasLength(2));
    expect(service.recorded.first.type, RfqNotificationEventType.rfqSent);
    expect(service.recorded.last.requestId, 'req');
  });
}
