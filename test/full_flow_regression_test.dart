import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/request_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequestItem _line(String id, String name) {
  return QuoteRequestItem(
    id: id,
    quoteRequestId: '',
    productId: 'p_$id',
    productName: name,
    category: 'כללי',
    unitType: 'יחידה',
    quantity: 1,
  );
}

AppUser _customer() {
  return AppUser(
    id: 'flow-customer',
    fullName: 'קבלן QA',
    email: 'contractor@qa.test',
    phone: '0501111111',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2024, 1, 1),
  );
}

AppUser _supplier(String id, String name) {
  return AppUser(
    id: id,
    fullName: name,
    email: '$id@qa.test',
    phone: '0502222222',
    userType: UserType.commercialSupplier,
    city: 'חיפה',
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  late QuoteService quoteService;

  setUp(() {
    AppMode.isDemoMode = true;
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
    quoteService = QuoteService();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  test('full contractor-supplier RFQ cycle with targeting and approval', () async {
    final customer = _customer();
    final supplierA = _supplier('sup-a', 'ספק ענק QA A');
    final supplierB = _supplier('sup-b', 'ספק ענק QA B');

    final requestIds = <String>[];
    for (var i = 0; i < 3; i++) {
      requestIds.add(
        await quoteService.submitQuoteRequest(
          customer: customer,
          requestItems: [_line('r$i-1', 'פריט $i')],
          requestType: RequestType.regular,
          invitedSupplierNames: const ['ספק ענק QA A', 'ספק ענק QA B'],
        ),
      );
    }
    for (var i = 0; i < 2; i++) {
      requestIds.add(
        await quoteService.submitQuoteRequest(
          customer: customer,
          requestItems: [_line('t$i-1', 'מכרז $i')],
          requestType: RequestType.tender,
          invitedSupplierNames: const ['ספק ענק QA A', 'ספק ענק QA B'],
        ),
      );
    }
    expect(requestIds, hasLength(5));

    final customerRequests = await quoteService
        .watchCustomerRequests(customer.id)
        .first;
    expect(customerRequests, hasLength(5));

    final requestId = requestIds.first;
    final incomingForA = await quoteService
        .watchIncomingRequestsForSupplier(supplierA.id)
        .first;
    expect(
      incomingForA.any((request) => request.id == requestId),
      isTrue,
    );

    final quoteIdA = await quoteService.submitSupplierQuote(
      supplier: supplierA,
      quoteRequestId: requestId,
      deliveryTime: '3 ימים',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: _line('r0-1', 'פריט 0'),
          unitPrice: 100,
          requestedQuantity: 1,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );
    final quoteIdB = await quoteService.submitSupplierQuote(
      supplier: supplierB,
      quoteRequestId: requestId,
      deliveryTime: '5 ימים',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: _line('r0-1', 'פריט 0'),
          unitPrice: 120,
          requestedQuantity: 1,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );

    final requestQuotes = await quoteService.watchQuotesForRequest(requestId).first;
    expect(requestQuotes.map((q) => q.id), containsAll([quoteIdA, quoteIdB]));

    await quoteService.rejectCustomerQuote(
      customerId: customer.id,
      requestId: requestId,
      quoteId: quoteIdB,
    );
    await quoteService.approveCustomerQuote(
      customerId: customer.id,
      requestId: requestId,
      quoteId: quoteIdA,
    );

    final approvedQuote = await quoteService.watchSupplierQuote(quoteIdA).first;
    final rejectedQuote = await quoteService.watchSupplierQuote(quoteIdB).first;
    expect(approvedQuote?.status, SupplierQuoteStatus.approved);
    expect(rejectedQuote?.status, SupplierQuoteStatus.rejected);

    await quoteService.markSupplierOrderShipped(
      supplierId: supplierA.id,
      requestId: requestId,
      quoteId: quoteIdA,
    );
    final shippedQuote = await quoteService.watchSupplierQuote(quoteIdA).first;
    expect(shippedQuote?.status, SupplierQuoteStatus.shipped);
  });
}
