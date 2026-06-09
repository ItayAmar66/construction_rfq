import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
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
        searchTokens: ['דבק', 'לבן'],
        skuLower: 'fx-1',
      ),
    ],
  );
}

void main() {
  group('production catalog path', () {
    test('productsProvider does not serve legacy seed in firebase mode', () async {
      AppMode.isDemoMode = false;
      AppMode.isFirebaseInitialized = true;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final products = await container.read(productsProvider.future);
      expect(products, isEmpty);
    });

    testWidgets('material catalog shows search field and categories', (tester) async {
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

      expect(find.text(HebrewStrings.catalogMaterialsTitle), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(HebrewStrings.catalogCategoriesSection), findsOneWidget);
      expect(find.text(HebrewStrings.catalogProductsSection), findsOneWidget);
      expect(find.text(HebrewStrings.pickFromCatalog), findsNothing);
      expect(find.text('בחר מהקטלוג'), findsNothing);
      expect(find.text('חפש מהקטלוג'), findsNothing);
    });

    testWidgets('search filters real repository results', (tester) async {
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

      await tester.enterText(find.byType(TextField), 'דבק');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('דבק פיקס'), findsOneWidget);
      expect(find.text(HebrewStrings.addRfqItem), findsOneWidget);
    });

    testWidgets('placeholder when variant has no image url', (tester) async {
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

      expect(find.byIcon(Icons.inventory_2_outlined), findsWidgets);
    });
  });
}
