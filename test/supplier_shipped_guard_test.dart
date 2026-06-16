import 'dart:io';

import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_doc_id.dart';
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

void main() {
  final rules =
      File('${Directory.current.path}/firestore.rules').readAsStringSync();

  group('Firestore shipped transition', () {
    test('requires approved supplier quote status', () {
      expect(rules, contains("resource.data.status in ['אושרה', 'approved']"));
      expect(rules, contains('supplierQuoteShippedUpdateAllowed()'));
      expect(rules, contains('supplierCanMarkOrderShipped()'));
    });
  });

  group('App supplier shipped guard', () {
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

    test('deterministic doc id uses supplier org', () {
      expect(
        SupplierQuoteDocId.forRequest(
          quoteRequestId: 'rfq-1',
          supplierId: 'owner-uid',
          supplierOrgId: 'supplier-org',
        ),
        'rfq-1__supplier-org',
      );
    });

    Future<String> createRequest(AppUser customer) {
      return quoteService.submitQuoteRequest(
        customer: customer,
        requestItems: [
          _line('req-line', 'פריט'),
        ],
      );
    }

    test('unapproved quote cannot be marked shipped', () async {
      final customer = AppUser(
        id: 'cust-1',
        fullName: 'Cust',
        email: 'c@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final supplier = AppUser(
        id: 'sup-1',
        fullName: 'Sup',
        email: 's@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final requestId = await createRequest(customer);
      final quoteId = await quoteService.submitSupplierQuote(
        supplier: supplier,
        quoteRequestId: requestId,
        deliveryTime: '2 ימים',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _line('r1', 'פריט'),
            unitPrice: 50,
            requestedQuantity: 1,
            includeInQuote: true,
            isExactMatch: true,
          ),
        ],
      );
      expect(
        MockStore.instance.supplierQuotes
            .firstWhere((q) => q.id == quoteId)
            .status,
        SupplierQuoteStatus.sent,
      );

      expect(
        () => quoteService.markSupplierOrderShipped(
          quoteId: quoteId,
          requestId: requestId,
          supplierId: supplier.id,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('approved quote can be marked shipped by owning supplier', () async {
      final customer = AppUser(
        id: 'cust-2',
        fullName: 'Cust',
        email: 'c2@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final supplier = AppUser(
        id: 'sup-2',
        fullName: 'Sup',
        email: 's2@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final requestId = await createRequest(customer);
      final quoteId = await quoteService.submitSupplierQuote(
        supplier: supplier,
        quoteRequestId: requestId,
        deliveryTime: '2 ימים',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _line('r2', 'פריט'),
            unitPrice: 50,
            requestedQuantity: 1,
            includeInQuote: true,
            isExactMatch: true,
          ),
        ],
      );
      await quoteService.approveCustomerQuote(
        actorUid: customer.id,
        requestId: requestId,
        quoteId: quoteId,
      );

      await quoteService.markSupplierOrderShipped(
        quoteId: quoteId,
        requestId: requestId,
        supplierId: supplier.id,
      );

      final shipped = await quoteService.watchSupplierQuote(quoteId).first;
      expect(shipped?.status, SupplierQuoteStatus.shipped);
    });

    test('unrelated supplier cannot mark order shipped', () async {
      final customer = AppUser(
        id: 'cust-3',
        fullName: 'Cust',
        email: 'c3@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final supplier = AppUser(
        id: 'sup-3',
        fullName: 'Sup',
        email: 's3@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final otherSupplier = AppUser(
        id: 'sup-other',
        fullName: 'Other',
        email: 'other@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'TLV',
        createdAt: DateTime(2026),
      );
      final requestId = await createRequest(customer);
      final quoteId = await quoteService.submitSupplierQuote(
        supplier: supplier,
        quoteRequestId: requestId,
        deliveryTime: '2 ימים',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _line('r3', 'פריט'),
            unitPrice: 50,
            requestedQuantity: 1,
            includeInQuote: true,
            isExactMatch: true,
          ),
        ],
      );
      await quoteService.approveCustomerQuote(
        actorUid: customer.id,
        requestId: requestId,
        quoteId: quoteId,
      );

      expect(
        () => quoteService.markSupplierOrderShipped(
          quoteId: quoteId,
          requestId: requestId,
          supplierId: otherSupplier.id,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
