import 'package:construction_rfq/models/catalog/catalog_search_query.dart';
import 'package:construction_rfq/providers/catalog_search_providers.dart';
import 'package:construction_rfq/providers/catalog_selector_provider.dart';
import 'package:construction_rfq/repositories/catalog_search/memory_catalog_search_repository.dart';
import 'package:construction_rfq/screens/catalog/catalog_selector_screen.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_selector_browse_test.dart';

class _EmptyCatalogRepository extends MemoryCatalogSearchRepository {
  _EmptyCatalogRepository() : super();
}

void main() {
  setUp(CatalogSelectorNotifier.clearSessionRecentsForTesting);

  testWidgets('empty catalog shows real-catalog-not-loaded blocking state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSearchRepositoryProvider.overrideWithValue(
            _EmptyCatalogRepository(),
          ),
        ],
        child: const MaterialApp(home: CatalogSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(HebrewStrings.catalogRealNotLoaded), findsOneWidget);
    expect(find.text('דבק פיקס'), findsNothing);
    expect(find.text('נסה שוב'), findsOneWidget);
  });

  testWidgets('real catalog repo never shows demo fallback banner', (tester) async {
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
  });

  testWidgets('search resets pagination on real repository', (tester) async {
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
}
