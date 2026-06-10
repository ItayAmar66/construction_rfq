import 'package:construction_rfq/models/catalog/catalog_image.dart';
import 'package:construction_rfq/models/catalog/catalog_product.dart';
import 'package:construction_rfq/models/catalog/catalog_search_hit.dart';
import 'package:construction_rfq/models/catalog/catalog_variant.dart';
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

    test('maps assets/images/foo.webp to catalog/images/foo.webp', () {
      expect(
        CatalogImageUrl.storageObjectPath(
          'assets/images/hash-id.jpg',
          'catalog/images',
        ),
        'catalog/images/hash-id.jpg',
      );
      const image = CatalogImage(localPath: 'assets/images/hash-id.jpg');
      final url = CatalogImageUrl.resolveDisplayUrl(image);
      expect(url, contains('catalog%2Fimages%2Fhash-id.jpg'));
      expect(url, isNot(contains('images%2Fimages')));
    });

    test('resolveHitImage uses variant then product image', () {
      const hitWithVariant = CatalogSearchHit(
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
          image: CatalogImage(localPath: 'images/v.webp'),
        ),
        product: CatalogProduct(
          id: 'p1',
          name: 'P',
          primaryCategoryId: '1',
          categoryIds: ['1'],
          nameLower: 'p',
          image: CatalogImage(localPath: 'images/p.webp'),
        ),
      );
      final variantUrl = CatalogImageUrl.resolveHitImage(hitWithVariant);
      expect(variantUrl, contains('v.webp'));

      const hitProductOnly = CatalogSearchHit(
        variant: CatalogVariant(
          id: 'v2',
          productId: 'p1',
          name: 'V2',
          displayName: 'P — V2',
          displayNameLower: 'p v2',
          categoryIds: ['1'],
          primaryCategoryId: '1',
          searchTokens: [],
          nameLower: 'v2',
        ),
        product: CatalogProduct(
          id: 'p1',
          name: 'P',
          primaryCategoryId: '1',
          categoryIds: ['1'],
          nameLower: 'p',
          image: CatalogImage(localPath: 'images/p.webp'),
        ),
      );
      final productUrl = CatalogImageUrl.resolveHitImage(hitProductOnly);
      expect(productUrl, contains('p.webp'));
    });

    test('ignores storage.googleapis.com URLs and uses localPath', () {
      const image = CatalogImage(
        url:
            'https://storage.googleapis.com/construction-rfq-itay-20-2eee0.firebasestorage.app/catalog/images/tile.webp',
        localPath: 'images/tile.webp',
      );
      final url = CatalogImageUrl.resolveDisplayUrl(image);
      expect(url, contains('firebasestorage.googleapis.com'));
      expect(url, contains('catalog%2Fimages%2Ftile.webp'));
      expect(url, isNot(startsWith('https://storage.googleapis.com/')));
    });

    test('returns null when no image data', () {
      expect(CatalogImageUrl.resolveDisplayUrl(const CatalogImage()), isNull);
    });
  });
}
