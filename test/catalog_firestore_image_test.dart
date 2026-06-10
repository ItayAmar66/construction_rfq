import 'package:construction_rfq/repositories/catalog/catalog_firestore_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogFirestoreConverter.imageFromDoc', () {
    test('uses top-level imageLocalPath when image map is empty', () {
      final image = CatalogFirestoreConverter.imageFromDoc({
        'image': <String, dynamic>{},
        'imageLocalPath': 'assets/images/tile-1.jpg',
      });
      expect(image.localPath, 'assets/images/tile-1.jpg');
      expect(image.url, isNull);
    });

    test('merges embedded image map with legacy top-level fields', () {
      final image = CatalogFirestoreConverter.imageFromDoc({
        'image': {'localPath': 'images/a.webp'},
        'imageUrl': 'https://cdn.example/a.webp',
        'imageThumbUrl': 'https://cdn.example/a-thumb.webp',
      });
      expect(image.localPath, 'images/a.webp');
      expect(image.url, 'https://cdn.example/a.webp');
      expect(image.thumbUrl, 'https://cdn.example/a-thumb.webp');
    });

    test('variantFromDoc resolves imageLocalPath-only documents', () {
      final variant = CatalogFirestoreConverter.variantFromDoc('v1', {
        'productId': 'p1',
        'name': 'Variant',
        'displayName': 'Product — Variant',
        'displayNameLower': 'product variant',
        'categoryIds': ['1'],
        'primaryCategoryId': '1',
        'searchTokens': <String>[],
        'nameLower': 'variant',
        'imageLocalPath': 'foo.webp',
        'isActive': true,
      });
      expect(variant.image.localPath, 'foo.webp');
    });

    test('productFromDoc resolves imageLocalPath-only documents', () {
      final product = CatalogFirestoreConverter.productFromDoc('p1', {
        'name': 'Tile',
        'categoryIds': ['1'],
        'primaryCategoryId': '1',
        'searchTokens': <String>[],
        'nameLower': 'tile',
        'imageLocalPath': 'images/tile.webp',
        'isActive': true,
      });
      expect(product.image.localPath, 'images/tile.webp');
    });
  });
}
