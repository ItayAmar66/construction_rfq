import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/catalog/catalog_image.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_search_hit.dart';
import '../models/catalog/catalog_variant.dart';

/// Resolves a network URL for catalog thumbnails (Firestore → Storage).
abstract final class CatalogImageUrl {
  static const defaultBasePath = 'catalog/images';
  static const _productionBucket = 'construction-rfq-itay-20-2eee0.firebasestorage.app';

  static String? resolveDisplayUrl(
    CatalogImage image, {
    String imageBasePath = defaultBasePath,
  }) {
    final thumb = normalizeRemoteUrl(image.thumbUrl);
    if (thumb != null) return thumb;

    final url = normalizeRemoteUrl(image.url);
    if (url != null) return url;

    final local = image.localPath?.trim();
    if (local == null || local.isEmpty) return null;

    final objectPath = storageObjectPath(local, imageBasePath);
    final downloadUrl = storageDownloadUrl(objectPath);
    _logResolved(localPath: local, objectPath: objectPath, url: downloadUrl);
    return downloadUrl;
  }

  /// Variant image first, then product image — shared by card and detail sheet.
  static String? resolveHitImage(CatalogSearchHit hit) {
    return resolveDisplayUrl(hit.variant.image) ??
        (hit.product != null ? resolveDisplayUrl(hit.product!.image) : null);
  }

  /// Firebase Storage SDK URL (tokenized); falls back to REST URL when SDK unavailable.
  static Future<String?> resolveHitImageAsync(CatalogSearchHit hit) async {
    final variantUrl = await resolveDisplayUrlAsync(hit.variant.image);
    if (variantUrl != null) return variantUrl;
    final product = hit.product;
    if (product == null) return null;
    return resolveDisplayUrlAsync(product.image);
  }

  static Future<String?> resolveDisplayUrlAsync(
    CatalogImage image, {
    String imageBasePath = defaultBasePath,
  }) async {
    final remote = normalizeRemoteUrl(image.thumbUrl) ??
        normalizeRemoteUrl(image.url);
    if (remote != null) return remote;

    final local = image.localPath?.trim();
    if (local == null || local.isEmpty) return null;

    final objectPath = storageObjectPath(local, imageBasePath);
    try {
      final ref = FirebaseStorage.instance.ref(objectPath);
      final url = await ref.getDownloadURL();
      _logResolved(localPath: local, objectPath: objectPath, url: url);
      return url;
    } catch (e) {
      final fallback = storageDownloadUrl(objectPath);
      if (kDebugMode) {
        debugPrint(
          '[CatalogImage] getDownloadURL failed for $objectPath: $e; '
          'fallback=$fallback',
        );
      }
      _logResolved(localPath: local, objectPath: objectPath, url: fallback);
      return fallback;
    }
  }

  static String? resolveVariantOrProduct({
    required CatalogVariant variant,
    CatalogProduct? product,
  }) {
    return resolveDisplayUrl(variant.image) ??
        (product != null ? resolveDisplayUrl(product.image) : null);
  }

  /// Drops raw GCS URLs (403 under Firebase Storage rules); keeps Firebase REST/CDN URLs.
  @visibleForTesting
  static String? normalizeRemoteUrl(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (lower.contains('storage.googleapis.com/')) {
      if (kDebugMode) {
        debugPrint(
          '[CatalogImage] ignoring storage.googleapis.com URL (use Firebase Storage): $trimmed',
        );
      }
      return null;
    }

    if (lower.startsWith('gs://')) {
      final objectPath = storageObjectPath(trimmed, defaultBasePath);
      return storageDownloadUrl(objectPath);
    }

    return trimmed;
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
      return normalizeRemoteUrl(objectPath);
    }

    final bucket = _storageBucket;
    if (bucket == null || bucket.isEmpty) return null;

    final encoded = Uri.encodeComponent(objectPath);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media';
  }

  static String? get _storageBucket {
    try {
      final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
      if (bucket != null && bucket.isNotEmpty && !bucket.contains('YOUR_')) {
        return bucket;
      }
    } catch (_) {
      // Test VM may not have a FirebaseOptions platform.
    }
    return _productionBucket;
  }

  static void _logResolved({
    required String localPath,
    required String objectPath,
    required String? url,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[CatalogImage] localPath=$localPath objectPath=$objectPath url=$url',
    );
  }
}
