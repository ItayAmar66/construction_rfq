import 'package:construction_rfq/providers/catalog_selector_provider.dart';
import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/screens/catalog/catalog_selector_screen.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(CatalogSelectorNotifier.clearSessionRecentsForTesting);

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

  testWidgets('loads browse results on open', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(testRepo()),
        ],
        child: const MaterialApp(
          home: CatalogSelectorScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('דבק פיקס'), findsOneWidget);
    expect(find.text(HebrewStrings.addRfqItem), findsOneWidget);
    expect(find.text(HebrewStrings.catalogSelectorPrompt), findsNothing);
  });

  testWidgets('category filter narrows browse results', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(testRepo()),
        ],
        child: const MaterialApp(
          home: CatalogSelectorScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'חיפוי'));
    await tester.pumpAndSettle();

    expect(find.text('דבק פיקס'), findsOneWidget);
    expect(find.text(HebrewStrings.catalogBrowsingCategory('חיפוי')),
        findsOneWidget);
  });

  testWidgets('clear category returns to full browse', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(testRepo()),
        ],
        child: const MaterialApp(
          home: CatalogSelectorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'חיפוי'));
    await tester.pumpAndSettle();
    expect(find.text(HebrewStrings.catalogBrowsingCategory('חיפוי')),
        findsOneWidget);

    await tester.tap(find.text(HebrewStrings.catalogClearCategory));
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogBrowsingCategory('חיפוי')),
        findsNothing);
    expect(find.text('דבק פיקס'), findsOneWidget);
  });

  testWidgets('select variant pops draft snapshot', (tester) async {
    CatalogRfqLineDraft? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(testRepo()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      selected = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CatalogSelectorScreen(),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(HebrewStrings.addRfqItem));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.variantId, 'v1');
    expect(selected!.isCatalogMatched, isTrue);
  });
}
