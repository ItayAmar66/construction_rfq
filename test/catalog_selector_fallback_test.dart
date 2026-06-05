import 'package:construction_rfq/data/demo_catalog_search_data.dart';
import 'package:construction_rfq/models/catalog/catalog_category.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_page.dart';
import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/providers/catalog_selector_provider.dart';
import 'package:construction_rfq/repositories/catalog_search/catalog_search_repository.dart';
import 'package:construction_rfq/repositories/catalog_search/fallback_catalog_search_repository.dart';
import 'package:construction_rfq/screens/catalog/catalog_selector_screen.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingCatalogSearchRepository implements CatalogSearchRepository {
  @override
  Future<List<CatalogCategory>> getCategoryTree() async {
    throw Exception('failed-precondition: missing index');
  }

  @override
  Future<CatalogSearchPage> browseVariantsByCategory(
    CatalogSearchQuery query,
  ) async {
    throw Exception('permission-denied');
  }

  @override
  Future<CatalogProduct?> getProductById(String productId) async {
    throw Exception('unavailable');
  }

  @override
  Future<CatalogVariant?> getVariantById(String variantId) async {
    throw Exception('unavailable');
  }

  @override
  Future<CatalogSearchPage> searchVariants(CatalogSearchQuery query) async {
    throw Exception('permission-denied');
  }
}

void main() {
  setUp(CatalogSelectorNotifier.clearSessionRecentsForTesting);

  testWidgets('shows demo fallback banner when Firestore catalog unavailable',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(
            FallbackCatalogSearchRepository(
              primary: _ThrowingCatalogSearchRepository(),
              fallback: DemoCatalogSearchData.repository(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CatalogSelectorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogDemoFallbackBanner), findsOneWidget);
    expect(find.text('חיפוי'), findsWidgets);

    await tester.tap(find.widgetWithText(FilterChip, 'חיפוי'));
    await tester.pumpAndSettle();

    expect(find.text('דבק פיקס'), findsWidgets);
    expect(find.text(HebrewStrings.addRfqItem), findsOneWidget);
  });
}
