import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/request_audit_event.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/utils/request_audit_trail.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:construction_rfq/widgets/request_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequest _request({
  QuoteRequestStatus status = QuoteRequestStatus.sent,
  String? approvedQuoteId,
}) {
  return QuoteRequest(
    id: 'req-1',
    customerId: 'c1',
    customerName: 'Customer',
    customerPhone: '050',
    customerCity: 'TLV',
    customerType: 'commercial',
    status: status,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 5),
    approvedQuoteId: approvedQuoteId,
  );
}

SupplierQuote _quote({required String id}) {
  return SupplierQuote(
    id: id,
    quoteRequestId: 'req-1',
    supplierId: 's1',
    supplierName: 'Supplier',
    supplierType: 'commercial',
    deliveryTime: '3d',
    totalPrice: 100,
    status: SupplierQuoteStatus.sent,
    createdAt: DateTime(2024, 1, 2),
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
  group('RequestTimeline', () {
    testWidgets('shows audit-aligned lifecycle labels', (tester) async {
      final request = _request(status: QuoteRequestStatus.quotesReceived);
      final quotes = [_quote(id: 'q1'), _quote(id: 'q2')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestTimeline(request: request, quotes: quotes),
          ),
        ),
      );

      expect(find.text('נשלח לספקים'), findsOneWidget);
      expect(find.text('התקבלו 2 הצעות'), findsOneWidget);
      expect(find.text('הצעה אושרה'), findsOneWidget);
      expect(find.text('בדרך'), findsOneWidget);
    });

    testWidgets('shipped request highlights final step', (tester) async {
      final request = _request(
        status: QuoteRequestStatus.shipped,
        approvedQuoteId: 'q1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestTimeline(
              request: request,
              quotes: [_quote(id: 'q1')],
            ),
          ),
        ),
      );

      expect(find.text(RequestAuditTrail.labelFor(RequestAuditEventType.shipped)),
          findsOneWidget);
    });
  });
}
