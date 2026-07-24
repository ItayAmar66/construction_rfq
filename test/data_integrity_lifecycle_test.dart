import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Data-integrity regressions for the RFQ → quote → order lifecycle.
///
/// These exercise the in-memory [MockStore] path, which mirrors the real
/// Firestore repositories, and lock in three invariants:
///   1. Cancelling an RFQ that has quotes retires those quotes (no orphaned
///      "active" supplier quotes pointing at a cancelled request).
///   2. An RFQ already in fulfillment (ordered+) cannot be cancelled, so an
///      approved quote can't be stranded in the supplier's fulfilment queue.
///   3. A supplier quote can only be shipped against the request it belongs
///      to (no cross-request stamping via a mismatched requestId).

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

AppUser _customer(String id) => AppUser(
      id: id,
      fullName: 'Customer $id',
      email: '$id@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'TLV',
      createdAt: DateTime(2026),
    );

AppUser _supplier(String id) => AppUser(
      id: id,
      fullName: 'Supplier $id',
      email: '$id@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'TLV',
      createdAt: DateTime(2026),
    );

void main() {
  late QuoteService quoteService;

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
    quoteService = QuoteService();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  Future<String> createRequest(AppUser customer) {
    return quoteService.submitQuoteRequest(
      customer: customer,
      requestItems: [_line('req-line', 'פריט')],
    );
  }

  Future<String> submitQuote(
    AppUser supplier,
    String requestId,
    String lineId,
  ) {
    return quoteService.submitSupplierQuote(
      supplier: supplier,
      quoteRequestId: requestId,
      deliveryTime: '2 ימים',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: _line(lineId, 'פריט'),
          unitPrice: 50,
          requestedQuantity: 1,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );
  }

  String statusOf(String quoteId) => MockStore.instance.supplierQuotes
      .firstWhere((q) => q.id == quoteId)
      .status;

  group('deleteOrCancelQuoteRequest data integrity', () {
    test('cancelling a request with quotes retires those quotes as outdated',
        () async {
      final customer = _customer('cust-cancel');
      final supplier = _supplier('sup-cancel');
      final requestId = await createRequest(customer);
      final quoteId = await submitQuote(supplier, requestId, 'r1');

      expect(statusOf(quoteId), SupplierQuoteStatus.sent);

      await quoteService.deleteOrCancelQuoteRequest(
        requestId: requestId,
        customerId: customer.id,
      );

      expect(
        MockStore.instance.getRequest(requestId)?.status,
        QuoteRequestStatus.cancelled,
      );
      // The quote must no longer appear active to the supplier.
      expect(statusOf(quoteId), SupplierQuoteStatus.outdated);
    });

    test('cannot cancel a request already in fulfillment (ordered)', () async {
      final customer = _customer('cust-locked');
      final supplier = _supplier('sup-locked');
      final requestId = await createRequest(customer);
      final quoteId = await submitQuote(supplier, requestId, 'r2');
      await quoteService.approveCustomerQuote(
        actorUid: customer.id,
        requestId: requestId,
        quoteId: quoteId,
      );
      expect(
        MockStore.instance.getRequest(requestId)?.status,
        QuoteRequestStatus.ordered,
      );

      await expectLater(
        quoteService.deleteOrCancelQuoteRequest(
          requestId: requestId,
          customerId: customer.id,
        ),
        throwsA(isA<Exception>()),
      );

      // Order and its approved quote stay intact.
      expect(
        MockStore.instance.getRequest(requestId)?.status,
        QuoteRequestStatus.ordered,
      );
      expect(statusOf(quoteId), SupplierQuoteStatus.approved);
    });
  });

  group('markSupplierOrderShipped linkage guard', () {
    test('cannot ship a quote against a mismatched requestId', () async {
      final customer = _customer('cust-link');
      final supplier = _supplier('sup-link');

      final requestA = await createRequest(customer);
      final quoteA = await submitQuote(supplier, requestA, 'ra');
      await quoteService.approveCustomerQuote(
        actorUid: customer.id,
        requestId: requestA,
        quoteId: quoteA,
      );

      final requestB = await createRequest(customer);
      final quoteB = await submitQuote(supplier, requestB, 'rb');
      await quoteService.approveCustomerQuote(
        actorUid: customer.id,
        requestId: requestB,
        quoteId: quoteB,
      );

      // Ship quoteA but point it at requestB — must be rejected.
      await expectLater(
        quoteService.markSupplierOrderShipped(
          quoteId: quoteA,
          requestId: requestB,
          supplierId: supplier.id,
        ),
        throwsA(isA<Exception>()),
      );

      // Neither the wrong request nor the quote advanced.
      expect(
        MockStore.instance.getRequest(requestB)?.status,
        QuoteRequestStatus.ordered,
      );
      expect(statusOf(quoteA), SupplierQuoteStatus.approved);
    });
  });
}
