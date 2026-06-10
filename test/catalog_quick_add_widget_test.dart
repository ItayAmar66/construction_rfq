import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/screens/catalog/catalog_selector_screen.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick add increments quantity badge on card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(
            MemoryCatalogSearchRepository(
              categories: const [
                CatalogCategory(id: '7', name: 'חיפוי', nameLower: 'חיפוי'),
              ],
              products: const [
                CatalogProduct(
                  id: '11',
                  name: 'דבק פיקס',
                  primaryCategoryId: '7',
                  categoryIds: ['7'],
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
                  nameLower: 'לבן',
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogAddedQuantity(1)), findsNothing);

    await tester.tap(find.text(HebrewStrings.addRfqItem).first);
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogAddedQuantity(1)), findsOneWidget);

    await tester.tap(find.text(HebrewStrings.catalogQuickAddMore).first);
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogAddedQuantity(2)), findsOneWidget);
  });
}
