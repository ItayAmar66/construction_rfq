import 'package:construction_rfq/models/catalog/catalog_image.dart';
import 'package:construction_rfq/utils/catalog_image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogImageUrl', () {
    test('prefers thumbUrl then url', () {
      const image = CatalogImage(
        thumbUrl: 'https://example.com/thumb.webp',
        url: 'https://example.com/full.webp',
        localPath: 'images/x.webp',
      );
      expect(
        CatalogImageUrl.resolveDisplayUrl(image),
        'https://example.com/thumb.webp',
      );
    });

    test('maps images/foo.webp to catalog/images/foo.webp without double prefix',
        () {
      expect(
        CatalogImageUrl.storageObjectPath('images/tile.webp', 'catalog/images'),
        'catalog/images/tile.webp',
      );
      const image = CatalogImage(localPath: 'images/tile.webp');
      final url = CatalogImageUrl.resolveDisplayUrl(image);
      expect(url, isNotNull);
      expect(url, contains('catalog%2Fimages%2Ftile.webp'));
      expect(url, isNot(contains('images%2Fimages')));
    });

    test('maps bare foo.webp to catalog/images/foo.webp', () {
      expect(
        CatalogImageUrl.storageObjectPath('foo.webp', 'catalog/images'),
        'catalog/images/foo.webp',
      );
    });

    test('preserves catalog/ prefix paths', () {
      expect(
        CatalogImageUrl.storageObjectPath(
          'catalog/images/foo.webp',
          'catalog/images',
        ),
        'catalog/images/foo.webp',
      );
    });

    test('returns null when no image data', () {
      expect(CatalogImageUrl.resolveDisplayUrl(const CatalogImage()), isNull);
    });
  });
}
