import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/customer_quote_match_helpers.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:construction_rfq/widgets/catalog/customer_quote_approval_dialog.dart';
import 'package:construction_rfq/widgets/catalog/customer_quote_line_match_card.dart';
import 'package:flutter/material.dart';
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

SupplierQuoteItem _exactQuoteItem() {
  return const SupplierQuoteItem(
    id: 'qi-exact',
    supplierQuoteId: 'q-1',
    productId: '11',
    productName: 'דבק פיקס — לבן',
    requestedQuantity: 2,
    unitPrice: 10,
    totalItemPrice: 20,
    requestItemId: 'req-line-catalog',
    variantId: 'v1',
    quotedName: 'דבק פיקס — לבן',
    quotedSku: 'FX-1',
    isExactMatch: true,
  );
}

SupplierQuoteItem _alternativeQuoteItem({String? supplierNotes}) {
  return SupplierQuoteItem(
    id: 'qi-alt',
    supplierQuoteId: 'q-1',
    productId: '11',
    productName: 'דבק דומה',
    requestedQuantity: 2,
    unitPrice: 9,
    totalItemPrice: 18,
    requestItemId: 'req-line-catalog',
    quotedName: 'דבק דומה',
    quotedSku: 'SUB-1',
    isAlternative: true,
    supplierNotes: supplierNotes ?? 'מלאי מוגבל',
  );
}

SupplierQuoteItem _manualQuoteItem() {
  return const SupplierQuoteItem(
    id: 'qi-manual',
    supplierQuoteId: 'q-1',
    productId: 'manual-1',
    productName: 'בלוק 20',
    requestedQuantity: 3,
    unitPrice: 5,
    totalItemPrice: 15,
    requestItemId: 'req-line-manual',
  );
}

SupplierQuote _sampleQuote() {
  return SupplierQuote(
    id: 'q-1',
    quoteRequestId: 'req-1',
    supplierId: 'sup-1',
    supplierName: 'ספק QA',
    supplierType: UserType.commercialSupplier.name,
    deliveryTime: '3 days',
    totalPrice: 100,
    status: SupplierQuoteStatus.sent,
    createdAt: DateTime(2024, 1, 1),
    totalInclVat: 100,
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
  group('customer quote match helpers', () {
    test('detects alternative items', () {
      expect(quoteHasAlternativeItems([_exactQuoteItem()]), isFalse);
      expect(
        quoteHasAlternativeItems([_exactQuoteItem(), _alternativeQuoteItem()]),
        isTrue,
      );
      expect(alternativeItemCount([_alternativeQuoteItem()]), 1);
    });

    test('manual lines skip catalog match UI', () {
      expect(
        shouldShowCatalogMatchUi(_manualQuoteItem(), _manualRequestLine()),
        isFalse,
      );
    });
  });

  group('CustomerQuoteLineMatchCard', () {
    testWidgets('displays exact match with requested snapshot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _exactQuoteItem(),
              requestLine: _catalogRequestLine(),
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.exactMatchBadge), findsOneWidget);
      expect(find.text(HebrewStrings.requestedCatalogItem), findsOneWidget);
      expect(find.text(HebrewStrings.supplierQuotedItem), findsOneWidget);
      expect(find.text('דבק פיקס — לבן'), findsWidgets);
    });

    testWidgets('displays alternative with supplier notes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _alternativeQuoteItem(),
              requestLine: _catalogRequestLine(),
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.alternativeMatchBadge), findsOneWidget);
      expect(find.text('דבק דומה'), findsOneWidget);
      expect(find.textContaining('מלאי מוגבל'), findsOneWidget);
      expect(find.text(HebrewStrings.catalogMatchedBadge), findsOneWidget);
    });

    testWidgets('manual line has no catalog badges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _manualQuoteItem(),
              requestLine: _manualRequestLine(),
            ),
          ),
        ),
      );

      expect(find.text('בלוק 20'), findsOneWidget);
      expect(find.text(HebrewStrings.exactMatchBadge), findsNothing);
      expect(find.text(HebrewStrings.alternativeMatchBadge), findsNothing);
      expect(find.text(HebrewStrings.catalogMatchedBadge), findsNothing);
    });

    testWidgets('compact exact match shows badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerQuoteLineMatchCard(
              quoteItem: _exactQuoteItem(),
              requestLine: _catalogRequestLine(),
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.exactMatchBadge), findsOneWidget);
      expect(find.textContaining('מבוקש'), findsOneWidget);
    });
  });

  group('CustomerQuoteApprovalDialog', () {
    testWidgets('shows warning when alternatives exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => CustomerQuoteApprovalDialog.show(
                  context: context,
                  quote: _sampleQuote(),
                  items: [_alternativeQuoteItem()],
                ),
                child: const Text('approve'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('approve'));
      await tester.pumpAndSettle();

      expect(find.textContaining('חלופ'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('אישור הצעה'), findsOneWidget);
    });

    testWidgets('no alternative warning for exact-only quote', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => CustomerQuoteApprovalDialog.show(
                  context: context,
                  quote: _sampleQuote(),
                  items: [_exactQuoteItem()],
                ),
                child: const Text('approve'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('approve'));
      await tester.pumpAndSettle();

      expect(find.textContaining('חלופ'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  group('customer quote approval', () {
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

    Future<String> seedRequestWithQuotes() async {
      final requestId = await quoteService.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_manualRequestLine(), _catalogRequestLine()],
      );
      await quoteService.submitSupplierQuote(
        supplier: _supplier(id: 'sup-1', name: 'Supplier A'),
        quoteRequestId: requestId,
        deliveryTime: '3 days',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _manualRequestLine(),
            unitPrice: 5,
            requestedQuantity: 3,
            includeInQuote: true,
          ),
        ],
      );
      await quoteService.submitSupplierQuote(
        supplier: _supplier(id: 'sup-2', name: 'Supplier B'),
        quoteRequestId: requestId,
        deliveryTime: '4 days',
        lines: [
          SupplierQuoteLineMapper.fromRequestLine(
            requestItem: _manualRequestLine(),
            unitPrice: 6,
            requestedQuantity: 3,
            includeInQuote: true,
          ),
        ],
      );
      return requestId;
    }

    test('manual quote approval succeeds', () async {
      final requestId = await seedRequestWithQuotes();
      final quoteId = MockStore.instance.supplierQuotes
          .firstWhere((q) => q.supplierId == 'sup-1')
          .id;

      await quoteService.approveCustomerQuote(
        quoteId: quoteId,
        requestId: requestId,
        customerId: 'cust-1',
      );

      final request = MockStore.instance.getRequest(requestId)!;
      expect(request.hasApprovedQuote, isTrue);
      expect(request.approvedQuoteId, quoteId);
    });

    test('only one quote can be approved per request', () async {
      final requestId = await seedRequestWithQuotes();
      final quotes = MockStore.instance.supplierQuotes
          .where((q) => q.quoteRequestId == requestId)
          .toList();

      await quoteService.approveCustomerQuote(
        quoteId: quotes.first.id,
        requestId: requestId,
        customerId: 'cust-1',
      );

      expect(
        () => quoteService.approveCustomerQuote(
          quoteId: quotes.last.id,
          requestId: requestId,
          customerId: 'cust-1',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('כבר אושרה הצעה אחרת'),
        )),
      );
    });
  });
}
