import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/screens/catalog/catalog_selector_screen.dart';
import 'package:construction_rfq/screens/customer/cart_screen.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/rfq_draft_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('RfqDraftSummary', () {
    test('summary counts catalog and manual lines', () {
      final summary = summarizeRfqDraft(const [
        QuoteRequestItem(
          id: '1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Catalog',
          category: 'c',
          unitType: 'u',
          quantity: 2,
          isCatalogMatched: true,
        ),
        QuoteRequestItem(
          id: '2',
          quoteRequestId: '',
          productId: 'p2',
          productName: 'Manual',
          category: 'c',
          unitType: 'u',
          quantity: 1,
        ),
      ]);

      expect(summary.totalLines, 2);
      expect(summary.catalogLines, 1);
      expect(summary.manualLines, 1);
      expect(summary.totalQuantity, 3);
    });
  });

  group('CartScreen builder sections', () {
    testWidgets('renders catalog and manual sections', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).addCatalogDraft(
            const CatalogRfqLineDraft(
              variantId: 'v1',
              productId: '11',
              categoryId: '7',
              categoryPath: 'cat',
              displayName: 'Catalog item',
            ),
          );
      container.read(rfqDraftProvider.notifier).addManualItem(
            productName: 'Manual item',
            category: 'cat',
            unitType: 'u',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, __) => const CartScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(HebrewStrings.rfqCatalogSection), findsOneWidget);
      expect(find.text(HebrewStrings.rfqManualSection), findsOneWidget);
      expect(find.text(HebrewStrings.rfqDraftSummary(2, 1, 1)), findsOneWidget);
    });
  });

  group('CatalogVariantResultCard', () {
    testWidgets('renders sku unit and category', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogSearchRepositoryProvider.overrideWithValue(
              MemoryCatalogSearchRepository(
                categories: const [],
                variants: const [
                  CatalogVariant(
                    id: 'v1',
                    productId: '11',
                    name: 'לבן',
                    displayName: 'דבק פיקס — לבן',
                    displayNameLower: 'x',
                    nameLower: 'x',
                    categoryIds: ['7'],
                    primaryCategoryId: '7',
                    categoryPathText: 'דבקים › חיפוי',
                    searchTokens: const ['x'],
                    skuLower: 'fx-1',
                  ),
                ],
                products: const [
                  CatalogProduct(
                    id: '11',
                    name: 'דבק פיקס',
                    sku: 'FX-1',
                    unitType: 'שק',
                    categoryIds: ['7'],
                    primaryCategoryId: '7',
                  ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(home: CatalogSelectorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'fx');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.textContaining('FX-1'), findsOneWidget);
      expect(find.text('דבקים › חיפוי'), findsOneWidget);
      expect(find.textContaining('שק'), findsOneWidget);
    });
  });
}
