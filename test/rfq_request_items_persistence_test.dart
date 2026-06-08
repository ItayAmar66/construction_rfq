import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:construction_rfq/repositories/request_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/quote_request_item_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _customer() {
  return AppUser(
    id: 'cust-items',
    fullName: 'Items Customer',
    email: 'items@test.com',
    phone: '0504444444',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2024, 1, 1),
  );
}

QuoteRequestItem _manualLine(String id, String name) {
  return QuoteRequestItem(
    id: id,
    quoteRequestId: '',
    productId: 'manual_$id',
    productName: name,
    category: 'כללי',
    unitType: 'יחידה',
    quantity: 2,
    isCatalogMatched: false,
  );
}

void main() {
  group('RFQ item line persistence', () {
    test('embedded map keeps stable line ids', () {
      const item = QuoteRequestItem(
        id: 'line-a',
        quoteRequestId: '',
        productId: 'manual_a',
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        quantity: 2,
      );

      final map = item.toEmbeddedMap();
      expect(map['id'], 'line-a');

      final restored = QuoteRequestItem.fromEmbedded(
        requestId: 'req-1',
        map: map,
        index: 0,
      );
      expect(restored.id, 'line-a');
      expect(restored.productName, 'בלוק 20');
    });

    test('submit persists 2 manual lines', () async {
      AppMode.isDemoMode = true;
      MockStore.instance.init();
      final repo = RequestRepository();
      final requestId = await repo.submitQuoteRequest(
        customer: _customer(),
        requestItems: [
          _manualLine('m1', 'בלוק 20'),
          _manualLine('m2', 'דבק'),
        ],
      );

      final items = await repo.getRequestItems(requestId);
      expect(items, hasLength(2));
      expect(items.map((i) => i.productName), ['בלוק 20', 'דבק']);
    });

    test('submit persists 4 manual lines', () async {
      AppMode.isDemoMode = true;
      MockStore.instance.init();
      final repo = RequestRepository();
      final requestId = await repo.submitQuoteRequest(
        customer: _customer(),
        requestItems: List.generate(
          4,
          (index) => _manualLine('m$index', 'פריט ${index + 1}'),
        ),
      );

      final items = await repo.getRequestItems(requestId);
      expect(items, hasLength(4));
    });

    test('submit persists mixed manual and catalog lines', () async {
      AppMode.isDemoMode = true;
      MockStore.instance.init();
      final repo = RequestRepository();
      final catalogLine = QuoteRequestItem.fromCatalogDraft(
        const CatalogRfqLineDraft(
          variantId: 'v1',
          productId: '11',
          categoryId: '7',
          categoryPath: 'חיפוי',
          displayName: 'דבק פיקס',
          unitType: 'שק',
          quantity: 1,
        ),
        lineId: 'c1',
      );

      final requestId = await repo.submitQuoteRequest(
        customer: _customer(),
        requestItems: [
          _manualLine('m1', 'בלוק 20'),
          catalogLine,
          _manualLine('m2', 'צבע'),
        ],
      );

      final items = await repo.getRequestItems(requestId);
      expect(items, hasLength(3));
      expect(items.where((i) => i.isCatalogMatched), hasLength(1));
      expect(items.where((i) => !i.isCatalogMatched), hasLength(2));
    });

    test('draft provider keeps distinct manual lines', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(rfqDraftProvider.notifier);
      notifier.addManualItem(
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
      );
      notifier.addManualItem(
        productName: 'דבק',
        category: 'דבקים',
        unitType: 'שק',
      );

      final resolved = resolveQuoteRequestItems(
        requestItems: container.read(rfqDraftProvider),
      );
      expect(resolved, hasLength(2));
    });
  });
}
