import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/screens/catalog/material_catalog_screen.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MemoryCatalogSearchRepository _repo() {
  return MemoryCatalogSearchRepository(
    categories: const [
      CatalogCategory(id: '7', name: 'חיפוי', nameLower: 'חיפוי'),
    ],
    products: const [
      CatalogProduct(
        id: '11',
        name: 'דבק פיקס',
        primaryCategoryId: '7',
        categoryIds: ['7'],
        sku: 'FX-1',
        nameLower: 'דבק פיקס',
      ),
    ],
    variants: const [
      CatalogVariant(
        id: 'v1',
        productId: '11',
        name: 'לבן',
        displayName: 'דבק פיקס — לבן',
        displayNameLower: 'דבק פיקס לבן',
        categoryIds: ['7'],
        primaryCategoryId: '7',
        searchTokens: ['דבק'],
        skuLower: 'fx-1',
      ),
    ],
  );
}

void main() {
  testWidgets('top button shows סל with count and not טיוטת בקשה', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MaterialCatalogScreen()),
        GoRoute(path: '/rfq-draft', builder: (_, __) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(_repo()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogCartLabel), findsOneWidget);
    expect(find.text(HebrewStrings.rfqDraftTitle), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogCartWithCount(1)), findsOneWidget);
    expect(find.text('פריט כבר בבקשה'), findsNothing);
  });

  testWidgets('decrement at quantity 1 removes item from draft', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const MaterialCatalogScreen()),
        GoRoute(path: '/rfq-draft', builder: (_, __) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(_repo()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNothing);
    expect(find.text(HebrewStrings.catalogCartLabel), findsOneWidget);
    expect(find.text(HebrewStrings.catalogCartWithCount(1)), findsNothing);
  });

  test('decrementCatalogVariant removes line at zero', () {
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
    notifier.decrementCatalogVariant('v1');
    expect(container.read(rfqDraftProvider), isEmpty);
  });

  test('manual item flow unchanged', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rfqDraftProvider.notifier);

    notifier.addManualItem(
      productName: 'בלוק',
      category: 'בלוקים',
      unitType: 'יחידה',
    );
    expect(container.read(rfqDraftProvider), hasLength(1));
    expect(container.read(rfqDraftProvider).first.isCatalogMatched, isFalse);
  });
}
