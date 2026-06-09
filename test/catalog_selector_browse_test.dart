import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/providers/catalog_selector_provider.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/screens/catalog/catalog_selector_screen.dart';
import 'package:construction_rfq/utils/catalog_search_constants.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'catalog_test_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<CatalogVariant> _manyVariants(int count) {
  return List.generate(
    count,
    (i) => CatalogVariant(
      id: 'v$i',
      productId: '11',
      name: 'v$i',
      displayName: 'דבק פיקס — $i',
      displayNameLower: 'דבק פיקס $i',
      categoryIds: const ['7'],
      primaryCategoryId: '7',
      searchTokens: ['דבק', '$i'],
      nameLower: 'v$i',
      skuLower: 'fx-$i',
      sortOrder: i,
    ),
  );
}

MemoryCatalogSearchRepository paginatedRepo({int variantCount = 55}) {
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
    variants: _manyVariants(variantCount),
  );
}

void main() {
  setUp(CatalogSelectorNotifier.clearSessionRecentsForTesting);

  test('CatalogSelectorNotifier uses page size 50', () {
    expect(CatalogSelectorNotifier.pageSize, CatalogSearchConstants.defaultPageSize);
    expect(CatalogSearchQuery().effectiveLimit, 50);
  });

  testWidgets('selector loads first browse page without search', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(paginatedRepo()),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogResultsSummary(50, hasMore: true)),
        findsOneWidget);
    expect(find.text(HebrewStrings.loadMore), findsOneWidget);
    expect(find.text(HebrewStrings.catalogSelectorPrompt), findsNothing);
  });

  testWidgets('load more appends next page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(paginatedRepo()),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(HebrewStrings.loadMore));
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogResultsSummary(55, hasMore: false)),
        findsOneWidget);
    expect(find.text(HebrewStrings.loadMore), findsNothing);
  });

  testWidgets('search resets pagination and filters results', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(paginatedRepo()),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fx-54');
    await tester.pumpAndSettle(const Duration(milliseconds: 350));

    expect(find.text('דבק פיקס'), findsOneWidget);
    expect(find.text(HebrewStrings.loadMore), findsNothing);
  });

  testWidgets('category + text keeps text filter active', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(paginatedRepo()),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await selectCatalogCategory(tester, 'חיפוי');

    await tester.enterText(find.byType(TextField).first, 'fx-54');
    await tester.pumpAndSettle(const Duration(milliseconds: 350));

    expect(find.text('דבק פיקס'), findsOneWidget);
    expectCategoryChipSelected(tester, 'חיפוי', selected: true);
  });

  testWidgets('category filter keeps load more for large category', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(paginatedRepo()),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await selectCatalogCategory(tester, 'חיפוי');

    expect(find.text(HebrewStrings.loadMore), findsOneWidget);
    expectCategoryChipSelected(tester, 'חיפוי', selected: true);
  });

  testWidgets('all categories picker reaches beyond chip row', (tester) async {
    final manyCategories = List.generate(
      60,
      (i) => CatalogCategory(
        id: 'c$i',
        name: 'קטגוריה $i',
        nameLower: 'קטגוריה $i',
        sortOrder: i,
      ),
    );
    final repo = MemoryCatalogSearchRepository(
      categories: manyCategories,
      products: const [
        CatalogProduct(
          id: '11',
          name: 'דבק פיקס',
          primaryCategoryId: 'c59',
          categoryIds: ['c59'],
          sku: 'FX-1',
          unitType: 'שק',
          nameLower: 'דבק פיקס',
        ),
      ],
      variants: [
        CatalogVariant(
          id: 'v1',
          productId: '11',
          name: 'v1',
          displayName: 'דבק פיקס',
          displayNameLower: 'דבק פיקס',
          categoryIds: const ['c59'],
          primaryCategoryId: 'c59',
          searchTokens: const ['דבק'],
          nameLower: 'v1',
          skuLower: 'fx-1',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(HebrewStrings.catalogAllCategoriesPicker));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'קטגוריה 59'), findsNothing);

    await tester.enterText(find.byType(TextField).last, '59');
    await tester.pumpAndSettle();

    await tester.tap(find.text('קטגוריה 59'));
    await tester.pumpAndSettle();

    expectCategoryChipSelected(tester, 'קטגוריה 59', selected: true);
  });
}
