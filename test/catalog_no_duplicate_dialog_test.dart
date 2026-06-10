import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog duplicate dialog is not used in normal add flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    final container = ProviderScope.containerOf(context);
                    final notifier = container.read(rfqDraftProvider.notifier);
                    notifier.addCatalogDraft(
                      const CatalogRfqLineDraft(
                        variantId: 'v1',
                        productId: 'p1',
                        displayName: 'Item',
                        categoryId: '1',
                        categoryPath: 'cat',
                        quantity: 1,
                        isCatalogMatched: true,
                      ),
                    );
                    notifier.addCatalogDraft(
                      const CatalogRfqLineDraft(
                        variantId: 'v1',
                        productId: 'p1',
                        displayName: 'Item',
                        categoryId: '1',
                        categoryPath: 'cat',
                        quantity: 1,
                        isCatalogMatched: true,
                      ),
                    );
                  },
                  child: const Text('add'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(find.text('פריט כבר בבקשה'), findsNothing);
    expect(find.text('הוסף כמות'), findsNothing);
    expect(find.text('שורה נפרדת'), findsNothing);
  });

  test('silent merge keeps one line with combined quantity', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rfqDraftProvider.notifier);

    notifier.addCatalogDraft(
      const CatalogRfqLineDraft(
        variantId: 'v1',
        productId: 'p1',
        displayName: 'Item',
        categoryId: '1',
        categoryPath: 'cat',
        quantity: 1,
        isCatalogMatched: true,
      ),
    );
    notifier.addCatalogDraft(
      const CatalogRfqLineDraft(
        variantId: 'v1',
        productId: 'p1',
        displayName: 'Item',
        categoryId: '1',
        categoryPath: 'cat',
        quantity: 1,
        isCatalogMatched: true,
      ),
    );

    final draft = container.read(rfqDraftProvider);
    expect(draft, hasLength(1));
    expect(draft.first.quantity, 2);
  });
}
