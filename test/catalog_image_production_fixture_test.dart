import 'package:construction_rfq/models/catalog/catalog_search_hit.dart';
import 'package:construction_rfq/repositories/catalog/catalog_firestore_converter.dart';
import 'package:construction_rfq/utils/catalog_image_url.dart';
import 'package:construction_rfq/widgets/catalog/catalog_product_image.dart';
import 'package:construction_rfq/widgets/catalog/catalog_variant_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production-shaped fixture from catalogVariants/21456 (Firestore REST).
Map<String, dynamic> productionVariant21456() => {
      'productId': '16',
      'name': "1 יח' - תרמוקיר AD 602 | אפור | 25 ק\"ג",
      'nameLower': '1 יח תרמוקיר ad 602 אפור 25 ק ג',
      'displayName': "תרמוקיר AD 602 — 1 יח' - תרמוקיר AD 602 | אפור | 25 ק\"ג",
      'displayNameLower': 'תרמוקיר ad 602 1 יח תרמוקיר ad 602 אפור 25 ק ג',
      'categoryIds': ['425', '417', '380', '379', '2', '7'],
      'primaryCategoryId': '7',
      'categoryPathText': 'דבקים וחומרי גמר › ריצוף וחיפוי › קרמיקה לחיפוי',
      'searchTokens': <String>['תרמוקיר'],
      'isActive': true,
      'sizeLabel': '1 UNIT',
      'status': 'Active',
      'sortOrder': 18,
      'image': <String, Object?>{
        'localPath': 'assets/images/08cea9e16bf06221-v0FAviwZK9jEDIik2Rh3s.jpg',
        'sha256': 'e0a97305db9bb676c1bb9a3be2e0f215235914fb3cecbbf6f9b2a2327e414694',
        'sizeBytes': 63744,
      },
      'imageLocalPath': 'assets/images/08cea9e16bf06221-v0FAviwZK9jEDIik2Rh3s.jpg',
    };

void main() {
  setUp(CatalogImageUrl.clearCacheForTesting);

  group('production catalog image fixture', () {
    test('converter reads nested image map without top-level imageLocalPath', () {
      final data = Map<String, dynamic>.from(productionVariant21456())
        ..remove('imageLocalPath');
      final variant = CatalogFirestoreConverter.variantFromDoc('21456', data);
      expect(
        variant.image.localPath,
        'assets/images/08cea9e16bf06221-v0FAviwZK9jEDIik2Rh3s.jpg',
      );
    });

    test('converter reads image.localPath and imageLocalPath', () {
      final variant =
          CatalogFirestoreConverter.variantFromDoc('21456', productionVariant21456());
      expect(variant.image.localPath,
          'assets/images/08cea9e16bf06221-v0FAviwZK9jEDIik2Rh3s.jpg');
      expect(variant.image.url, isNull);
      expect(variant.image.thumbUrl, isNull);
    });

    test('resolver builds Firebase REST URL with encoded slashes', () {
      final variant =
          CatalogFirestoreConverter.variantFromDoc('21456', productionVariant21456());
      final url = CatalogImageUrl.resolveDisplayUrl(variant.image);
      expect(url, isNotNull);
      expect(
        url,
        'https://firebasestorage.googleapis.com/v0/b/construction-rfq-itay-20-2eee0.firebasestorage.app/o/catalog%2Fimages%2F08cea9e16bf06221-v0FAviwZK9jEDIik2Rh3s.jpg?alt=media',
      );
      expect(url, isNot(startsWith('https://storage.googleapis.com/')));
      expect(url, isNot(contains('images%2Fimages')));
    });

    test('card and detail share resolveHitImage URL', () {
      final variant =
          CatalogFirestoreConverter.variantFromDoc('21456', productionVariant21456());
      final hit = CatalogSearchHit(variant: variant);
      final url = CatalogImageUrl.resolveHitImage(hit);
      expect(url, contains('firebasestorage.googleapis.com'));
      expect(url, contains('catalog%2Fimages%2F'));
    });

    testWidgets('product card shows image widget when URL resolved', (tester) async {
      final variant =
          CatalogFirestoreConverter.variantFromDoc('21456', productionVariant21456());
      final hit = CatalogSearchHit(variant: variant);
      final url = CatalogImageUrl.resolveHitImage(hit);
      expect(url, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogVariantResultCard(
              hit: hit,
              onOpenDetail: () {},
              onQuickAdd: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CatalogProductImage), findsOneWidget);
      expect(url, isNotNull);
    });
  });
}
