import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/catalog/catalog_image.dart';
import '../models/catalog/catalog_product.dart';
import '../models/catalog/catalog_search_hit.dart';
import '../models/catalog/catalog_variant.dart';

/// Resolves catalog image URLs — sync Firebase REST first, cached by objectPath.
abstract final class CatalogImageUrl {
  static const defaultBasePath = 'catalog/images';
  static const _productionBucket =
      'construction-rfq-itay-20-2eee0.firebasestorage.app';

  static final Map<String, String> _restUrlByObjectPath = {};
  static final Map<String, String> _tokenUrlByObjectPath = {};
  static final Map<String, Future<String?>> _tokenFetchByObjectPath = {};

  @visibleForTesting
  static void clearCacheForTesting() {
    _restUrlByObjectPath.clear();
    _tokenUrlByObjectPath.clear();
    _tokenFetchByObjectPath.clear();
  }

  @visibleForTesting
  static Map<String, String> get restUrlCache =>
      Map.unmodifiable(_restUrlByObjectPath);

  /// Sync URL for UI — no per-build getDownloadURL.
  static String? resolveDisplayUrl(
    CatalogImage image, {
    String imageBasePath = defaultBasePath,
  }) {
    final thumb = normalizeRemoteUrl(image.thumbUrl);
    if (thumb != null) return thumb;

    final url = normalizeRemoteUrl(image.url);
    if (url != null) return url;

    final objectPath = objectPathForImage(image, imageBasePath: imageBasePath);
    if (objectPath == null) return null;

    return restUrlForObjectPath(objectPath);
  }

  /// Variant image first, then product image — shared by card and detail sheet.
  static String? resolveHitImage(CatalogSearchHit hit) {
    return resolveDisplayUrl(hit.variant.image) ??
        (hit.product != null ? resolveDisplayUrl(hit.product!.image) : null);
  }

  /// Object storage path for [image], or null when no resolvable local/remote path.
  @visibleForTesting
  static String? objectPathForImage(
    CatalogImage image, {
    String imageBasePath = defaultBasePath,
  }) {
    final local = image.localPath?.trim();
    if (local == null || local.isEmpty) return null;
    return storageObjectPath(local, imageBasePath);
  }

  /// Cached public REST media URL for [objectPath].
  @visibleForTesting
  static String? restUrlForObjectPath(String objectPath) {
    final cached = _restUrlByObjectPath[objectPath];
    if (cached != null) return cached;

    final url = storageDownloadUrl(objectPath);
    if (url == null) return null;

    _restUrlByObjectPath[objectPath] = url;
    if (kDebugMode) {
      debugPrint('[CatalogImage] REST $objectPath');
    }
    return url;
  }

  /// Tokenized URL — only when REST load fails; result is cached.
  static Future<String?> tokenUrlForObjectPath(String objectPath) async {
    final cached = _tokenUrlByObjectPath[objectPath];
    if (cached != null) return cached;

    final inFlight = _tokenFetchByObjectPath[objectPath];
    if (inFlight != null) return inFlight;

    final future = _fetchTokenUrl(objectPath);
    _tokenFetchByObjectPath[objectPath] = future;
    try {
      final url = await future;
      if (url != null) {
        _tokenUrlByObjectPath[objectPath] = url;
      }
      return url;
    } finally {
      _tokenFetchByObjectPath.remove(objectPath);
    }
  }

  static Future<String?> _fetchTokenUrl(String objectPath) async {
    try {
      final ref = FirebaseStorage.instance.ref(objectPath);
      final url = await ref.getDownloadURL();
      if (kDebugMode) {
        debugPrint('[CatalogImage] token $objectPath');
      }
      return url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CatalogImage] token failed $objectPath');
      }
      return null;
    }
  }

  static Future<String?> tokenUrlForHit(CatalogSearchHit hit) async {
    final objectPath = objectPathForImage(hit.variant.image) ??
        (hit.product != null ? objectPathForImage(hit.product!.image) : null);
    if (objectPath == null) return null;
    return tokenUrlForObjectPath(objectPath);
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
      return null;
    }

    if (lower.startsWith('gs://')) {
      final objectPath = storageObjectPath(trimmed, defaultBasePath);
      return restUrlForObjectPath(objectPath);
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
}
