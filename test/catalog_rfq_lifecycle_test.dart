import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/customer_quote_match_helpers.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequestItem _manualLine() {
  return const QuoteRequestItem(
    id: 'req-manual',
    quoteRequestId: '',
    productId: 'manual-1',
    productName: 'בלוק 20',
    category: 'בלוקים',
    unitType: 'יחידה',
    quantity: 3,
    isCatalogMatched: false,
  );
}

QuoteRequestItem _catalogLine() {
  return QuoteRequestItem.fromCatalogDraft(
    const CatalogRfqLineDraft(
      variantId: 'v1',
      productId: '11',
      categoryId: '7',
      categoryPath: 'דבקים › חיפוי',
      displayName: 'דבק פיקס — לבן',
      sku: 'FX-1',
      unitType: 'שק',
      quantity: 2,
    ),
    lineId: 'req-catalog',
  );
}

AppUser _customer() {
  return AppUser(
    id: 'cust-lifecycle',
    fullName: 'Lifecycle Customer',
    email: 'lc@test.com',
    phone: '0501111111',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2024, 1, 1),
  );
}

AppUser _supplier({required String id, required String name}) {
  return AppUser(
    id: id,
    fullName: name,
    email: '$id@test.com',
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

  group('catalog RFQ lifecycle', () {
    test('full flow: manual + catalog RFQ through approval', () async {
      // 1–2. Customer adds manual + catalog items and submits RFQ.
      final requestId = await quoteService.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_manualLine(), _catalogLine()],
      );
      final storedRequest = MockStore.instance.getRequest(requestId)!;
      expect(storedRequest.items, hasLength(2));
      expect(storedRequest.items.where((i) => i.isCatalogMatched), hasLength(1));

      // 3–4. Supplier A: exact catalog + manual lines.
      final exactQuoteId = await quoteService.submitSupplierQuote(
        supplier: _supplier(id: 'sup-exact', name: 'Exact Supplier'),
        quoteRequestId: requestId,
        deliveryTime: '2 days',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _manualLine(),
            unitPrice: 5,
            requestedQuantity: 3,
            includeInQuote: true,
          ),
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _catalogLine(),
            unitPrice: 10,
            requestedQuantity: 2,
            includeInQuote: true,
            isExactMatch: true,
          ),
        ],
      );

      // 5. Supplier B: alternative on catalog line.
      final altQuoteId = await quoteService.submitSupplierQuote(
        supplier: _supplier(id: 'sup-alt', name: 'Alt Supplier'),
        quoteRequestId: requestId,
        deliveryTime: '4 days',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _manualLine(),
            unitPrice: 6,
            requestedQuantity: 3,
            includeInQuote: true,
          ),
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _catalogLine(),
            unitPrice: 8,
            requestedQuantity: 2,
            includeInQuote: true,
            isExactMatch: false,
            quotedName: 'דבק דומה',
            quotedSku: 'ALT-1',
            supplierNotes: 'חלופה מאושרת',
          ),
        ],
      );

      final exactItems = MockStore.instance.getSupplierQuoteItems(exactQuoteId);
      final altItems = MockStore.instance.getSupplierQuoteItems(altQuoteId);

      // 6–7. Customer compare data: exact vs alternative.
      expect(exactItems.any((i) => i.isExactMatch), isTrue);
      expect(altItems.any((i) => i.isAlternative), isTrue);
      expect(quoteHasAlternativeItems(exactItems), isFalse);
      expect(quoteHasAlternativeItems(altItems), isTrue);
      expect(alternativeItemCount(altItems), 1);

      // 8–9. Approve alternative quote; second approval blocked.
      await quoteService.approveCustomerQuote(
        quoteId: altQuoteId,
        requestId: requestId,
        customerId: _customer().id,
      );

      final afterApprove = MockStore.instance.getRequest(requestId)!;
      expect(afterApprove.approvedQuoteId, altQuoteId);
      expect(
        () => quoteService.approveCustomerQuote(
          quoteId: exactQuoteId,
          requestId: requestId,
          customerId: _customer().id,
        ),
        throwsA(isA<Exception>()),
      );

      // 10. Supplier sent quote retains match context on lines.
      final approvedQuote = MockStore.instance.supplierQuotes
          .firstWhere((q) => q.id == altQuoteId);
      expect(approvedQuote.status, SupplierQuoteStatus.approved);
      final catalogQuoted = altItems.firstWhere((i) => i.isAlternative);
      expect(catalogQuoted.quotedName, 'דבק דומה');
      expect(catalogQuoted.supplierNotes, 'חלופה מאושרת');

      // Manual line still works without catalog flags.
      final manualQuoted = altItems.firstWhere((i) => i.requestItemId == 'req-manual');
      expect(manualQuoted.isExactMatch, isFalse);
      expect(manualQuoted.isAlternative, isFalse);
      expect(
        shouldShowCatalogMatchUi(manualQuoted, _manualLine()),
        isFalse,
      );
    });
  });
}
