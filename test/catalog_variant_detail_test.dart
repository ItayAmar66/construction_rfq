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
  testWidgets('tapping details opens product detail sheet', (tester) async {
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
                  sku: 'FX-1',
                  unitType: 'שק',
                  nameLower: 'דבק פיקס',
                  descriptionPlain: 'דבק איכותי לחיפוי',
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
                  searchTokens: ['דבק'],
                  nameLower: 'לבן',
                  skuLower: 'fx-1',
                ),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(HebrewStrings.details).first);
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogProductDetails), findsOneWidget);
    expect(find.text('דבק פיקס'), findsWidgets);
    expect(find.text(HebrewStrings.addRfqItem), findsWidgets);
  });
}
