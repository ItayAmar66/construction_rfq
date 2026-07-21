import 'package:construction_rfq/analytics/catalog_rfq_analytics.dart';
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

class _RecordingCatalogRfqAnalytics implements CatalogRfqAnalytics {
  final events = <MapEntry<String, Map<String, Object?>?>>[];

  @override
  void track(String name, [Map<String, Object?>? params]) {
    events.add(MapEntry(name, params));
  }
}

void main() {
  testWidgets(
      'catalog_item_selected fires once per selection, not once per quantity bump',
      (tester) async {
    final analytics = _RecordingCatalogRfqAnalytics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRfqAnalyticsProvider.overrideWithValue(analytics),
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

    await tester.tap(find.byTooltip(HebrewStrings.addRfqItem));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(HebrewStrings.increaseQuantity));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(HebrewStrings.increaseQuantity));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);

    final selections = analytics.events
        .where((e) => e.key == CatalogRfqEventNames.catalogItemSelected)
        .toList();
    expect(selections, hasLength(1));
    expect(selections.single.value?['source'], 'quick_add');
  });
}
