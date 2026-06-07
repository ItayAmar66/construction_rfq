import 'package:construction_rfq/models/product.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RFQ manual + catalog regression', () {
    test('draft holds mixed manual and catalog lines', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).addCatalogDraft(
            const CatalogRfqLineDraft(
              variantId: 'v1',
              productId: '11',
              categoryId: '7',
              categoryPath: 'חיפוי',
              displayName: 'דבק פיקס',
              unitType: 'שק',
              quantity: 2,
            ),
          );
      container.read(rfqDraftProvider.notifier).addManualItem(
            productName: 'בלוק 20',
            category: 'בלוקים',
            unitType: 'יחידה',
            quantity: 10,
          );

      final draft = container.read(rfqDraftProvider);
      expect(draft.length, 2);
      expect(draft.where((l) => l.isCatalogMatched).length, 1);
      expect(draft.where((l) => !l.isCatalogMatched).length, 1);
    });

    test('manual item maps to quote request item', () {
      final item = QuoteRequestItem.fromLegacyProduct(
        product: const Product(
          id: 'manual',
          name: 'בלוק',
          category: 'ב',
          variant: '',
          unitType: 'יח',
          description: '',
        ),
        quantity: 5,
        lineId: 'm1',
      );
      expect(item.isCatalogMatched, isFalse);
      expect(item.productName, 'בלוק');
    });

    test('rfq wording constants avoid cart semantics', () {
      expect(HebrewStrings.addRfqItem, contains('בקשה'));
      expect(HebrewStrings.submitRequest, 'שליחה לספקים');
    });
  });
}
