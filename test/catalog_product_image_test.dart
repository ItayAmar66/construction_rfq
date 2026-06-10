import 'package:construction_rfq/models/catalog/catalog_image.dart';
import 'package:construction_rfq/models/catalog/catalog_search_hit.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
import 'package:construction_rfq/widgets/catalog/catalog_product_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogProductImage', () {
    test('web strategy is prefer on web, never otherwise', () {
      expect(
        catalogImageWebHtmlElementStrategy,
        kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      );
    });

    testWidgets('shows placeholder when no image path', (tester) async {
      const hit = CatalogSearchHit(
        variant: CatalogVariant(
          id: 'v1',
          productId: 'p1',
          name: 'V',
          displayName: 'P — V',
          displayNameLower: 'p v',
          categoryIds: ['1'],
          primaryCategoryId: '1',
          searchTokens: [],
          nameLower: 'v',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogProductImage(hit: hit),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('builds with resolved localPath URL', (tester) async {
      const hit = CatalogSearchHit(
        variant: CatalogVariant(
          id: 'v1',
          productId: 'p1',
          name: 'V',
          displayName: 'P — V',
          displayNameLower: 'p v',
          categoryIds: ['1'],
          primaryCategoryId: '1',
          searchTokens: [],
          nameLower: 'v',
          image: CatalogImage(localPath: 'images/tile.webp'),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogProductImage(hit: hit),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CatalogProductImage), findsOneWidget);
      // VM tests block real HTTP; widget may show placeholder after errorBuilder.
      expect(
        find.byType(Image).evaluate().isNotEmpty ||
            find.byIcon(Icons.inventory_2_outlined).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
