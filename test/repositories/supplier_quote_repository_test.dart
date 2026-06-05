import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/repositories/request_repository.dart';
import 'package:construction_rfq/repositories/supplier_quote_repository.dart';
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
  return const QuoteRequestItem(
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
    id: 'cust-sq-repo-test',
    fullName: 'Supplier Quote Repo Customer',
    email: 'sqrepo@test.com',
    phone: '0504444444',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2024, 1, 1),
  );
}

AppUser _supplier() {
  return AppUser(
    id: 'sup-sq-repo-test',
    fullName: 'Supplier Quote Repo Supplier',
    email: 'supplier@sqrepo.test',
    phone: '0505555555',
    userType: UserType.commercialSupplier,
    city: 'חיפה',
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  late RequestRepository requestRepository;
  late SupplierQuoteRepository repository;

  setUp(() {
    AppMode.isDemoMode = true;
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
    requestRepository = RequestRepository();
    repository = SupplierQuoteRepository();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  group('SupplierQuoteRepository demo mode', () {
    Future<String> seedOpenRequest() {
      return requestRepository.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_manualRequestLine(), _catalogRequestLine()],
      );
    }

    test('submitSupplierQuote + getSupplierQuoteItems round-trip exact match',
        () async {
      final requestId = await seedOpenRequest();
      final quoteId = await repository.submitSupplierQuote(
        supplier: _supplier(),
        quoteRequestId: requestId,
        deliveryTime: '3 days',
        lines: [
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

      final items = await repository.getSupplierQuoteItems(quoteId);

      expect(items, hasLength(1));
      final catalog = items.single;
      expect(catalog.isExactMatch, isTrue);
      expect(catalog.isAlternative, isFalse);
      expect(catalog.requestItemId, 'req-line-catalog');
      expect(catalog.variantId, 'v1');
      expect(catalog.quotedName, 'דבק פיקס — לבן');
      expect(catalog.quotedSku, 'FX-1');
      expect(catalog.supplierNotes, 'במלאי');
    });

    test('submitSupplierQuote + getSupplierQuoteItems round-trip alternative',
        () async {
      final requestId = await seedOpenRequest();
      final quoteId = await repository.submitSupplierQuote(
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

      final items = await repository.getSupplierQuoteItems(quoteId);

      expect(items, hasLength(1));
      final catalog = items.single;
      expect(catalog.isAlternative, isTrue);
      expect(catalog.isExactMatch, isFalse);
      expect(catalog.variantId, isNull);
      expect(catalog.displayName, 'דבק דומה');
      expect(catalog.quotedSku, 'SUB-1');
    });

    test('toEmbeddedMap preserves isExactMatch and isAlternative flags', () {
      final exactLine = SupplierQuoteLineInput(
        productId: '11',
        productName: 'דבק פיקס — לבן',
        requestedQuantity: 2,
        unitPrice: 10,
        totalItemPrice: 20,
        isExactMatch: true,
        isAlternative: false,
      );
      final altLine = SupplierQuoteLineInput(
        productId: '11',
        productName: 'דבק דומה',
        requestedQuantity: 2,
        unitPrice: 9,
        totalItemPrice: 18,
        isExactMatch: false,
        isAlternative: true,
      );

      expect(exactLine.toEmbeddedMap()['isExactMatch'], isTrue);
      expect(exactLine.toEmbeddedMap()['isAlternative'], isFalse);
      expect(altLine.toEmbeddedMap()['isExactMatch'], isFalse);
      expect(altLine.toEmbeddedMap()['isAlternative'], isTrue);
    });
  });
}
