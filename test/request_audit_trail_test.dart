import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/request_audit_event.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/request_audit_trail.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequest _request({
  QuoteRequestStatus status = QuoteRequestStatus.sent,
  String? approvedQuoteId,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return QuoteRequest(
    id: 'req-1',
    customerId: 'c1',
    customerName: 'Customer',
    customerPhone: '050',
    customerCity: 'תל אביב',
    customerType: 'commercial',
    status: status,
    createdAt: createdAt ?? DateTime(2024, 1, 1, 9),
    updatedAt: updatedAt ?? DateTime(2024, 1, 5, 12),
    approvedQuoteId: approvedQuoteId,
  );
}

SupplierQuote _quote({
  required String id,
  required DateTime createdAt,
  String supplierName = 'Supplier',
}) {
  return SupplierQuote(
    id: id,
    quoteRequestId: 'req-1',
    supplierId: 's1',
    supplierName: supplierName,
    supplierType: 'commercial',
    deliveryTime: '3d',
    totalPrice: 100,
    status: SupplierQuoteStatus.sent,
    createdAt: createdAt,
    items: const [
      SupplierQuoteItem(
        id: 'qi1',
        supplierQuoteId: 'q1',
        productId: 'p1',
        productName: 'Item',
        requestedQuantity: 1,
        unitPrice: 100,
        totalItemPrice: 100,
      ),
    ],
  );
}

void main() {
  group('RequestAuditTrail', () {
    test('labels map to Hebrew lifecycle copy', () {
      expect(
        RequestAuditTrail.labelFor(RequestAuditEventType.draftCreated),
        'טיוטה נוצרה',
      );
      expect(
        RequestAuditTrail.labelFor(RequestAuditEventType.sent),
        'נשלח לספקים',
      );
      expect(
        RequestAuditTrail.labelFor(RequestAuditEventType.supplierQuoted),
        'ספק הגיש הצעה',
      );
      expect(
        RequestAuditTrail.labelFor(RequestAuditEventType.quoteApproved),
        'הצעה אושרה',
      );
      expect(
        RequestAuditTrail.labelFor(RequestAuditEventType.shipped),
        'בדרך',
      );
    });

    test('orders events chronologically through shipped lifecycle', () {
      final request = _request(
        status: QuoteRequestStatus.shipped,
        approvedQuoteId: 'q2',
        createdAt: DateTime(2024, 1, 1, 9),
        updatedAt: DateTime(2024, 1, 6, 15),
      );
      final quotes = [
        _quote(id: 'q1', createdAt: DateTime(2024, 1, 2, 10)),
        _quote(id: 'q2', createdAt: DateTime(2024, 1, 3, 11)),
      ];

      final events = RequestAuditTrail.build(request: request, quotes: quotes);

      expect(events.map((e) => e.type).toList(), [
        RequestAuditEventType.draftCreated,
        RequestAuditEventType.sent,
        RequestAuditEventType.supplierQuoted,
        RequestAuditEventType.supplierQuoted,
        RequestAuditEventType.quoteApproved,
        RequestAuditEventType.shipped,
      ]);
      expect(events.first.label, 'טיוטה נוצרה');
      expect(events.last.label, 'בדרך');
      expect(events[2].detail, 'Supplier');
    });

    test('sent request without quotes only has draft and sent', () {
      final events = RequestAuditTrail.build(
        request: _request(status: QuoteRequestStatus.sent),
      );

      expect(events.length, 2);
      expect(events[0].type, RequestAuditEventType.draftCreated);
      expect(events[1].type, RequestAuditEventType.sent);
    });
  });
}
