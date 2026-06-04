import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:construction_rfq/screens/customer/cart_screen.dart';
import 'package:construction_rfq/screens/customer/product_catalog_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

QuoteRequestItem _manualLine({String? notes, int quantity = 2}) {
  return QuoteRequestItem(
    id: 'manual-1',
    quoteRequestId: '',
    productId: 'manual-product',
    productName: 'בלוק 20',
    category: 'בלוקים',
    unitType: 'יחידה',
    quantity: quantity,
    notes: notes,
    isCatalogMatched: false,
  );
}

QuoteRequestItem _catalogLine({String? notes, int quantity = 3}) {
  return QuoteRequestItem.fromCatalogDraft(
    CatalogRfqLineDraft(
      variantId: 'v1',
      productId: '11',
      categoryId: '7',
      categoryPath: 'דבקים › חיפוי',
      displayName: 'דבק פיקס — לבן',
      sku: 'FX-1',
      unitType: 'שק',
      packagingLabel: '25 ק״ג',
      quantity: quantity,
      notes: notes ?? '',
    ),
    lineId: 'catalog-1',
  );
}

AppUser _testCustomer() {
  return AppUser(
    id: 'cust-qa',
    fullName: 'QA Customer',
    email: 'qa@test.com',
    phone: '0500000000',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
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

  group('RFQ catalog flow QA — persist', () {
    test('submit saves manual and catalog lines with snapshot fields', () async {
      final manual = _manualLine(notes: 'ידני');
      final catalog = _catalogLine(notes: 'מהקטלוג');

      final requestId = await quoteService.submitQuoteRequest(
        customer: _testCustomer(),
        requestItems: [manual, catalog],
        notes: 'בקשה QA',
      );

      final saved = MockStore.instance.quoteRequests
          .firstWhere((request) => request.id == requestId);
      expect(saved.items, hasLength(2));
      expect(saved.notes, 'בקשה QA');

      final savedManual = saved.items.firstWhere((i) => !i.isCatalogMatched);
      expect(savedManual.productName, 'בלוק 20');
      expect(savedManual.quantity, 2);
      expect(savedManual.notes, 'ידני');
      expect(savedManual.variantId, isNull);

      final savedCatalog = saved.items.firstWhere((i) => i.isCatalogMatched);
      expect(savedCatalog.variantId, 'v1');
      expect(savedCatalog.productId, '11');
      expect(savedCatalog.categoryId, '7');
      expect(savedCatalog.categoryPath, 'דבקים › חיפוי');
      expect(savedCatalog.productName, 'דבק פיקס — לבן');
      expect(savedCatalog.sku, 'FX-1');
      expect(savedCatalog.quantity, 3);
      expect(savedCatalog.notes, 'מהקטלוג');
    });

    test('embedded item maps round-trip catalog flags and snapshots', () {
      final catalog = _catalogLine();
      final embedded = catalog.toEmbeddedMap();
      final restored = QuoteRequestItem.fromEmbedded(
        requestId: 'req-1',
        map: embedded,
        index: 0,
        idOverride: catalog.id,
      );

      expect(restored.isCatalogMatched, isTrue);
      expect(restored.variantId, 'v1');
      expect(restored.productId, '11');
      expect(restored.categoryId, '7');
      expect(restored.categoryPath, 'דבקים › חיפוי');
      expect(restored.sku, 'FX-1');
      expect(restored.productName, 'דבק פיקס — לבן');
    });
  });

  group('RFQ catalog flow QA — edit and duplicate', () {
    test('updateQuoteRequest keeps catalog snapshots after edits', () async {
      final requestId = await quoteService.submitQuoteRequest(
        customer: _testCustomer(),
        requestItems: [_manualLine(), _catalogLine()],
      );

      final editedManual = _manualLine(quantity: 5, notes: 'עודכן');
      final editedCatalog = _catalogLine(quantity: 7, notes: 'גרסה מעודכנת');

      await quoteService.updateQuoteRequest(
        requestId: requestId,
        customerId: _testCustomer().id,
        items: [editedManual, editedCatalog],
        notes: 'עריכה QA',
      );

      final saved = MockStore.instance.quoteRequests
          .firstWhere((request) => request.id == requestId);
      final catalog = saved.items.firstWhere((i) => i.isCatalogMatched);

      expect(saved.notes, 'עריכה QA');
      expect(catalog.variantId, 'v1');
      expect(catalog.quantity, 7);
      expect(catalog.notes, 'גרסה מעודכנת');
      expect(catalog.isCatalogMatched, isTrue);
    });

    test('duplicate draft replaceAll preserves catalog snapshot fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final original = [_manualLine(), _catalogLine(notes: 'שמור')];
      container.read(rfqDraftProvider.notifier).replaceAll(original);

      final duplicated = container.read(rfqDraftProvider);
      expect(duplicated, hasLength(2));

      final catalog = duplicated.firstWhere((i) => i.isCatalogMatched);
      expect(catalog.variantId, 'v1');
      expect(catalog.productId, '11');
      expect(catalog.categoryPath, 'דבקים › חיפוי');
      expect(catalog.sku, 'FX-1');
      expect(catalog.notes, 'שמור');
    });

    test('draft provider updates quantity and line notes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(rfqDraftProvider.notifier);
      notifier.addManualItem(
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        notes: 'ראשוני',
      );
      notifier.addCatalogDraft(
        const CatalogRfqLineDraft(
          variantId: 'v1',
          productId: '11',
          categoryId: '7',
          categoryPath: 'דבקים › חיפוי',
          displayName: 'דבק פיקס — לבן',
          sku: 'FX-1',
          unitType: 'שק',
        ),
      );

      final manualId = container.read(rfqDraftProvider).first.id;
      notifier.updateQuantity(manualId, 4);
      notifier.updateLineNotes(manualId, 'מעודכן');

      final draft = container.read(rfqDraftProvider);
      final manual = draft.firstWhere((i) => !i.isCatalogMatched);
      expect(manual.quantity, 4);
      expect(manual.notes, 'מעודכן');
      expect(draft.where((i) => i.isCatalogMatched), hasLength(1));
    });

    test('rfqDraftCountProvider reflects quantity changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(rfqDraftCountProvider), 0);

      container.read(rfqDraftProvider.notifier).addManualItem(
            productName: 'בלוק',
            category: 'בלוקים',
            unitType: 'יחידה',
            quantity: 2,
          );
      expect(container.read(rfqDraftCountProvider), 2);

      final lineId = container.read(rfqDraftProvider).single.id;
      container.read(rfqDraftProvider.notifier).updateQuantity(lineId, 5);
      expect(container.read(rfqDraftCountProvider), 5);
    });
  });

  group('RFQ catalog flow QA — RFQ copy', () {
    testWidgets('cart screen uses RFQ wording not cart/checkout copy', (tester) async {
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, __) => const CartScreen())],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(HebrewStrings.emptyRfqDraft), findsOneWidget);
      expect(find.text(HebrewStrings.pickFromCatalog), findsOneWidget);
      expect(find.text(HebrewStrings.addManualRfqItem), findsOneWidget);
      expect(find.text('העגלה ריקה'), findsNothing);
      expect(find.text('הוסף לסל'), findsNothing);
      expect(find.text(HebrewStrings.rfqDraftTitle), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
      expect(find.byIcon(Icons.add_shopping_cart_outlined), findsNothing);
    });

    testWidgets('legacy catalog browse links to RFQ draft with procurement icon',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const ProductCatalogScreen()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.request_quote_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsNothing);
    });
  });
}
