import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/catalog/catalog_image.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_search_hit.dart';
import '../models/catalog/catalog_variant.dart';

/// Resolves a network URL for catalog thumbnails (Firestore → Storage).
abstract final class CatalogImageUrl {
  static const defaultBasePath = 'catalog/images';

  static String? resolveDisplayUrl(
    CatalogImage image, {
    String imageBasePath = defaultBasePath,
  }) {
    final thumb = image.thumbUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;

    final url = image.url?.trim();
    if (url != null && url.isNotEmpty) return url;

    final local = image.localPath?.trim();
    if (local == null || local.isEmpty) return null;

    return storageDownloadUrl(storageObjectPath(local, imageBasePath));
  }

  /// Variant image first, then product image — shared by card and detail sheet.
  static String? resolveHitImage(CatalogSearchHit hit) {
    return resolveDisplayUrl(hit.variant.image) ??
        (hit.product != null ? resolveDisplayUrl(hit.product!.image) : null);
  }

  static String? resolveVariantOrProduct({
    required CatalogVariant variant,
    CatalogProduct? product,
  }) {
    return resolveDisplayUrl(variant.image) ??
        (product != null ? resolveDisplayUrl(product.image) : null);
  }

  /// Maps Firestore [localPath] to Storage object path under [imageBasePath].
  @visibleForTesting
  static String storageObjectPath(String localPath, String imageBasePath) {
    final normalized = localPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return normalized;

    if (normalized.startsWith('gs://')) {
      final withoutScheme = normalized.substring('gs://'.length);
      final slash = withoutScheme.indexOf('/');
      if (slash >= 0) return withoutScheme.substring(slash + 1);
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    if (normalized.startsWith('catalog/')) {
      return normalized;
    }

    final fileName = normalized.split('/').where((p) => p.isNotEmpty).last;
    if (fileName.isEmpty) return '$imageBasePath/$normalized';

    // assets/images/foo.webp, images/foo.webp, or foo.webp → catalog/images/foo.webp
    return '$imageBasePath/$fileName';
  }

  @visibleForTesting
  static String? storageDownloadUrl(String objectPath) {
    return _storageDownloadUrl(objectPath);
  }

  static String? _storageDownloadUrl(String objectPath) {
    if (objectPath.startsWith('http://') || objectPath.startsWith('https://')) {
      return objectPath;
    }

    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket == null || bucket.isEmpty || bucket.contains('YOUR_')) {
      return null;
    }
    final encoded = Uri.encodeComponent(objectPath);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media';
  }
}
