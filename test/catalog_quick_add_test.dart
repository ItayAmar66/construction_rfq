import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogRfqLineDraft _draft({String variantId = 'v1', int quantity = 1}) {
  return CatalogRfqLineDraft(
    variantId: variantId,
    productId: 'p1',
    displayName: 'דבק פיקס — לבן',
    productName: 'דבק פיקס',
    categoryId: '7',
    categoryPath: 'חיפוי',
    unitType: 'שק',
    quantity: quantity,
    isCatalogMatched: true,
  );
}

void main() {
  test('quick add merges quantity on same variant', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rfqDraftProvider.notifier);

    notifier.quickAddCatalogVariant(_draft());
    expect(container.read(rfqDraftProvider), hasLength(1));
    expect(container.read(rfqDraftProvider).first.quantity, 1);

    notifier.quickAddCatalogVariant(_draft());
    expect(container.read(rfqDraftProvider), hasLength(1));
    expect(container.read(rfqDraftProvider).first.quantity, 2);

    final quantities = container.read(catalogDraftQuantityByVariantProvider);
    expect(quantities['v1'], 2);
  });

  test('detail add quantity then quick add increments total', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rfqDraftProvider.notifier);

    notifier.addCatalogDraft(_draft(quantity: 3));
    expect(container.read(rfqDraftProvider).first.quantity, 3);

    notifier.quickAddCatalogVariant(_draft());
    expect(container.read(rfqDraftProvider), hasLength(1));
    expect(container.read(rfqDraftProvider).first.quantity, 4);
  });

  test('decrement removes catalog variant at quantity zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rfqDraftProvider.notifier);

    notifier.quickAddCatalogVariant(_draft());
    notifier.decrementCatalogVariant('v1');
    expect(container.read(rfqDraftProvider), isEmpty);
  });

  test('manual items stay separate from catalog quick add', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rfqDraftProvider.notifier);

    notifier.quickAddCatalogVariant(_draft());
    notifier.addManualItem(
      productName: 'בלוק 20',
      category: 'בלוקים',
      unitType: 'יחידה',
    );

    expect(container.read(rfqDraftProvider), hasLength(2));
    expect(container.read(catalogDraftQuantityByVariantProvider)['v1'], 1);
  });
}
