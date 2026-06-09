import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/request_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:construction_rfq/providers/supplier_directory_provider.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_targeting_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogRfqLineDraft _catalogDraft({String variantId = 'v1'}) {
  return CatalogRfqLineDraft(
    variantId: variantId,
    productId: 'p1',
    displayName: 'דבק פיקס — לבן',
    productName: 'דבק פיקס',
    categoryId: '7',
    categoryPath: 'חיפוי',
    unitType: 'שק',
    sku: 'FX-1',
    quantity: 1,
    isCatalogMatched: true,
  );
}

void main() {
  setUp(() {
    AppMode.isDemoMode = true;
    AppMode.isFirebaseInitialized = false;
    MockStore.instance.init();
    MockStore.instance.logout();
  });

  group('stress flow helpers', () {
    test('supplier directory includes QA stress suppliers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final suppliers = await container.read(supplierDirectoryProvider.future);
      expect(
        suppliers.map((s) => s.fullName),
        contains(SupplierTargetingHelpers.qaStressSupplierA),
      );
      expect(
        suppliers.map((s) => s.fullName),
        contains(SupplierTargetingHelpers.qaStressSupplierB),
      );
    });

    test('duplicate catalog merge and separate line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(rfqDraftProvider.notifier);

      notifier.addCatalogDraft(_catalogDraft());
      expect(container.read(rfqDraftProvider), hasLength(1));
      expect(container.read(rfqDraftProvider).first.quantity, 1);

      notifier.addCatalogDraft(_catalogDraft());
      expect(container.read(rfqDraftProvider), hasLength(1));
      expect(container.read(rfqDraftProvider).first.quantity, 2);

      notifier.addCatalogDraft(_catalogDraft(), forceSeparateLine: true);
      expect(container.read(rfqDraftProvider), hasLength(2));
    });

    test('repeated manual items stay separate', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(rfqDraftProvider.notifier);

      for (var i = 0; i < 3; i++) {
        notifier.addManualItem(
          productName: 'בלוק 20',
          category: 'בלוקים',
          unitType: 'יחידה',
          quantity: 1,
          notes: 'הערה $i',
        );
      }
      final draft = container.read(rfqDraftProvider);
      expect(draft, hasLength(3));
      expect(draft.map((l) => l.notes).toSet(), hasLength(3));
    });

    test('manual quantity and notes persist', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(rfqDraftProvider.notifier);

      notifier.addManualItem(
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
      );
      final lineId = container.read(rfqDraftProvider).single.id;
      notifier.updateQuantity(lineId, 5);
      notifier.updateLineNotes(lineId, 'קומה 3');

      final line = container.read(rfqDraftProvider).single;
      expect(line.quantity, 5);
      expect(line.notes, 'קומה 3');
    });

    test('targeted stress suppliers receive incoming requests', () async {
      MockStore.instance.loginAsDemo(UserType.commercialCustomer);
      final customer = MockStore.instance.currentUser!;
      final quoteService = QuoteService();

      final requestId = await quoteService.submitQuoteRequest(
        customer: customer,
        requestItems: [
          ...List.generate(
            8,
            (i) => containerLine(i),
          ),
        ],
        requestType: RequestType.regular,
        invitedSupplierIds: [MockStore.stressSupplierA.id],
        invitedSupplierNames: [MockStore.stressSupplierA.fullName],
      );

      MockStore.instance.currentUser = MockStore.stressSupplierA;
      final incoming = await quoteService
          .watchIncomingRequestsForSupplier(MockStore.stressSupplierA.id)
          .first;

      expect(incoming.any((r) => r.id == requestId), isTrue);
      expect(incoming.first.invitedSupplierNames, contains(MockStore.stressSupplierA.fullName));

      MockStore.instance.currentUser = MockStore.stressSupplierB;
      final hidden = await quoteService
          .watchIncomingRequestsForSupplier(MockStore.stressSupplierB.id)
          .first;
      expect(hidden.any((r) => r.id == requestId), isFalse);
    });

    test('contractor can submit multiple request types', () async {
      MockStore.instance.loginAsDemo(UserType.commercialCustomer);
      final customer = MockStore.instance.currentUser!;
      final quoteService = QuoteService();
      final ids = <String>[];

      for (var i = 0; i < 3; i++) {
        ids.add(
          await quoteService.submitQuoteRequest(
            customer: customer,
            requestItems: [containerLine(i)],
            requestType: RequestType.regular,
            invitedSupplierNames: [SupplierTargetingHelpers.qaStressSupplierA],
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        ids.add(
          await quoteService.submitQuoteRequest(
            customer: customer,
            requestItems: [containerLine(i + 10)],
            requestType: RequestType.tender,
            invitedSupplierNames: [SupplierTargetingHelpers.qaStressSupplierB],
          ),
        );
      }

      expect(ids, hasLength(5));
      expect(ids.toSet(), hasLength(5));
    });
  });
}

QuoteRequestItem containerLine(int index) {
  return QuoteRequestItem(
    id: 'line-$index',
    quoteRequestId: '',
    productId: 'manual_$index',
    productName: 'פריט $index',
    category: 'כללי',
    unitType: 'יחידה',
    quantity: 1,
    isCatalogMatched: false,
  );
}
