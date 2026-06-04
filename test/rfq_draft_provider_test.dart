import 'package:construction_rfq/models/cart_item.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/product.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RfqDraftNotifier', () {
    test('addCatalogDraft appends catalog-matched line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).addCatalogDraft(
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

      final draft = container.read(rfqDraftProvider);
      expect(draft, hasLength(1));
      expect(draft.first.isCatalogMatched, isTrue);
      expect(draft.first.variantId, 'v1');
    });

    test('addManualItem appends unmatched line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).addManualItem(
            productName: 'בלוק 20',
            category: 'בלוקים',
            unitType: 'יחידה',
          );

      final draft = container.read(rfqDraftProvider);
      expect(draft, hasLength(1));
      expect(draft.first.isCatalogMatched, isFalse);
      expect(draft.first.productName, 'בלוק 20');
    });

    test('importLegacyCart converts legacy products to manual lines', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).importLegacyCart([
        const CartItem(
          product: Product(
            id: 'legacy-1',
            name: 'צבע',
            category: 'צבעים',
            unitType: 'גלון',
            brand: '',
            sku: '',
            description: '',
            variant: '',
          ),
          quantity: 2,
        ),
      ]);

      final draft = container.read(rfqDraftProvider);
      expect(draft, hasLength(1));
      expect(draft.first.isCatalogMatched, isFalse);
      expect(draft.first.productId, 'legacy-1');
      expect(draft.first.quantity, 2);
    });
  });
}
