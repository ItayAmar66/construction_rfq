import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequestItem _catalogRequestLine() {
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
    lineId: 'req-line-catalog',
  );
}

QuoteRequestItem _manualRequestLine() {
  return QuoteRequestItem(
    id: 'req-line-manual',
    quoteRequestId: '',
    productId: 'manual-1',
    productName: 'בלוק 20',
    category: 'בלוקים',
    unitType: 'יחידה',
    quantity: 3,
    isCatalogMatched: false,
  );
}

AppUser _customer() {
  return AppUser(
    id: 'cust-1',
    fullName: 'Customer QA',
    email: 'c@test.com',
    phone: '0501111111',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2024, 1, 1),
  );
}

AppUser _supplier() {
  return AppUser(
    id: 'sup-1',
    fullName: 'Supplier QA',
    email: 's@test.com',
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

  group('SupplierQuoteLineMapper', () {
    test('exact catalog line sets match flags and variant snapshot', () {
      final input = SupplierQuoteLineMapper.fromRequestLine(
        requestItem: _catalogRequestLine(),
        unitPrice: 10,
        requestedQuantity: 2,
        includeInQuote: true,
        isExactMatch: true,
      );

      expect(input.isExactMatch, isTrue);
      expect(input.isAlternative, isFalse);
      expect(input.requestItemId, 'req-line-catalog');
      expect(input.variantId, 'v1');
      expect(input.productId, '11');
      expect(input.quotedName, 'דבק פיקס — לבן');
      expect(input.quotedSku, 'FX-1');
      expect(input.totalItemPrice, 20);
    });

    test('alternative catalog line clears variant and uses quoted fields', () {
      final input = SupplierQuoteLineMapper.fromRequestLine(
        requestItem: _catalogRequestLine(),
        unitPrice: 8,
        requestedQuantity: 2,
        includeInQuote: true,
        isExactMatch: false,
        quotedName: 'דבק חלופי',
        quotedSku: 'ALT-9',
      );

      expect(input.isExactMatch, isFalse);
      expect(input.isAlternative, isTrue);
      expect(input.variantId, isNull);
      expect(input.quotedName, 'דבק חלופי');
      expect(input.quotedSku, 'ALT-9');
    });

    test('manual line has no catalog match flags', () {
      final input = SupplierQuoteLineMapper.fromRequestLine(
        requestItem: _manualRequestLine(),
        unitPrice: 5,
        requestedQuantity: 3,
        includeInQuote: true,
      );

      expect(input.isExactMatch, isFalse);
      expect(input.isAlternative, isFalse);
      expect(input.variantId, isNull);
      expect(input.quotedName, isNull);
      expect(input.productName, 'בלוק 20');
    });
  });

  group('Supplier quote persistence', () {
    Future<String> _seedOpenRequest() {
      return quoteService.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_manualRequestLine(), _catalogRequestLine()],
      );
    }

    test('submit exact catalog quote preserves match fields', () async {
      final requestId = await _seedOpenRequest();
      final quoteId = await quoteService.submitSupplierQuote(
        supplier: _supplier(),
        quoteRequestId: requestId,
        deliveryTime: '3 days',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _manualRequestLine(),
            unitPrice: 5,
            requestedQuantity: 3,
            includeInQuote: true,
          ),
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _catalogRequestLine(),
            unitPrice: 10,
            requestedQuantity: 2,
            includeInQuote: true,
            isExactMatch: true,
            supplierNotes: 'במלאי',
          ),
        ],
      );

      final items = MockStore.instance.getSupplierQuoteItems(quoteId);
      expect(items, hasLength(2));

      final manual = items.firstWhere((i) => !i.isExactMatch && !i.isAlternative);
      expect(manual.productName, 'בלוק 20');
      expect(manual.variantId, isNull);

      final catalog = items.firstWhere((i) => i.isExactMatch);
      expect(catalog.requestItemId, 'req-line-catalog');
      expect(catalog.variantId, 'v1');
      expect(catalog.quotedName, 'דבק פיקס — לבן');
      expect(catalog.quotedSku, 'FX-1');
      expect(catalog.supplierNotes, 'במלאי');
    });

    test('submit alternative catalog quote preserves substitute fields', () async {
      final requestId = await _seedOpenRequest();
      final quoteId = await quoteService.submitSupplierQuote(
        supplier: _supplier(),
        quoteRequestId: requestId,
        deliveryTime: '5 days',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _catalogRequestLine(),
            unitPrice: 9,
            requestedQuantity: 2,
            includeInQuote: true,
            isExactMatch: false,
            quotedName: 'דבק דומה',
            quotedSku: 'SUB-1',
          ),
        ],
      );

      final catalog = MockStore.instance.getSupplierQuoteItems(quoteId).single;
      expect(catalog.isAlternative, isTrue);
      expect(catalog.isExactMatch, isFalse);
      expect(catalog.variantId, isNull);
      expect(catalog.displayName, 'דבק דומה');
      expect(catalog.quotedSku, 'SUB-1');
    });

    test('embedded quote item round-trips match flags for customer compare', () {
      const item = SupplierQuoteItem(
        id: 'qi-1',
        supplierQuoteId: 'q-1',
        productId: '11',
        productName: 'דבק דומה',
        requestedQuantity: 2,
        unitPrice: 9,
        totalItemPrice: 18,
        requestItemId: 'req-line-catalog',
        quotedName: 'דבק דומה',
        quotedSku: 'SUB-1',
        isExactMatch: false,
        isAlternative: true,
      );

      final restored = SupplierQuoteItem.fromEmbedded(
        quoteId: 'q-1',
        map: item.toEmbeddedMap(),
        index: 0,
        idOverride: item.id,
      );

      expect(restored.isAlternative, isTrue);
      expect(restored.displayName, 'דבק דומה');
      expect(restored.quotedSku, 'SUB-1');
    });
  });
}
