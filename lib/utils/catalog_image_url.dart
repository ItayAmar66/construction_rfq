import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/catalog/catalog_image.dart';

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

    return _storageDownloadUrl(storageObjectPath(local, imageBasePath));
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
