import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/screens/customer/cart_screen.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _testHarness({
  required Widget child,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => child),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  MemoryCatalogSearchRepository testRepo() {
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
          unitType: 'שק',
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
          categoryPathText: 'דבקים › חיפוי',
          searchTokens: ['דבק', 'לבן'],
          nameLower: 'לבן',
          skuLower: 'fx-1',
        ),
      ],
    );
  }

  testWidgets('cart screen opens catalog selector and adds draft line', (tester) async {
    await tester.pumpWidget(
      _testHarness(
        child: const CartScreen(),
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(testRepo()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.pickFromCatalog), findsOneWidget);
    await tester.tap(find.text(HebrewStrings.pickFromCatalog));
    await tester.pumpAndSettle();

    await tester.tap(find.text('חיפוי'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(HebrewStrings.addRfqItem));
    await tester.pumpAndSettle();

    expect(find.text('דבק פיקס — לבן'), findsOneWidget);
    expect(find.text(HebrewStrings.catalogMatchedBadge), findsOneWidget);
  });

  testWidgets('manual item adds unmatched line on cart screen', (tester) async {
    await tester.pumpWidget(
      _testHarness(child: const CartScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(HebrewStrings.addManualRfqItem));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, HebrewStrings.rfqItemName),
      'בלוק 20',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, HebrewStrings.category),
      'בלוקים',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, HebrewStrings.unit),
      'יחידה',
    );
    await tester.tap(find.text(HebrewStrings.addRfqItem));
    await tester.pumpAndSettle();

    expect(find.text('בלוק 20'), findsOneWidget);
    expect(find.text(HebrewStrings.catalogMatchedBadge), findsNothing);
  });
}
