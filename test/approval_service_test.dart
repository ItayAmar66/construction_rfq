import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/services/approval_service.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequest _request({String? approvedQuoteId}) {
  return QuoteRequest(
    id: 'req',
    customerId: 'c1',
    customerName: 'C',
    customerPhone: '050',
    customerCity: 'TLV',
    customerType: 'commercial',
    status: QuoteRequestStatus.quotesReceived,
    createdAt: DateTime(2024),
    approvedQuoteId: approvedQuoteId,
  );
}

SupplierQuote _quote({String status = SupplierQuoteStatus.sent}) {
  return SupplierQuote(
    id: 'q1',
    quoteRequestId: 'req',
    supplierId: 's1',
    supplierName: 'S',
    supplierType: 'commercial',
    deliveryTime: '2d',
    totalPrice: 10,
    status: status,
    createdAt: DateTime(2024),
    items: const [],
  );
}

void main() {
  test('validateApproval rejects wrong customer', () {
    expect(
      () => ApprovalService.validateApproval(
        request: _request(),
        quote: _quote(),
        actorUid: 'other',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('alternative warning when quote has alternatives', () {
    const items = [
      SupplierQuoteItem(
        id: 'i1',
        supplierQuoteId: 'q1',
        productId: 'p1',
        productName: 'Alt',
        requestedQuantity: 1,
        unitPrice: 1,
        totalItemPrice: 1,
        isAlternative: true,
      ),
    ];
    expect(ApprovalService.hasAlternativeLines(items), isTrue);
    expect(ApprovalService.alternativeWarningMessage(items), contains('חלופ'));
  });
}
