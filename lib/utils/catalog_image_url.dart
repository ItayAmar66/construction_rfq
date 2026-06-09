import '../firebase_options.dart';
import '../models/catalog/catalog_image.dart';

/// Resolves a network URL for catalog thumbnails (Firestore → Storage).
abstract final class CatalogImageUrl {
  static String? resolveDisplayUrl(
    CatalogImage image, {
    String imageBasePath = 'catalog/images',
  }) {
    final thumb = image.thumbUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;

    final url = image.url?.trim();
    if (url != null && url.isNotEmpty) return url;

    final local = image.localPath?.trim();
    if (local == null || local.isEmpty) return null;

    return _storageDownloadUrl(_storageObjectPath(local, imageBasePath));
  }

  static String _storageObjectPath(String localPath, String imageBasePath) {
    if (localPath.startsWith('catalog/')) return localPath;
    if (localPath.startsWith('images/')) {
      return '$imageBasePath/${localPath.substring('images/'.length)}';
    }
    return '$imageBasePath/$localPath';
  }

  static String? _storageDownloadUrl(String objectPath) {
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket == null || bucket.isEmpty || bucket.contains('YOUR_')) {
      return null;
    }
    final encoded = Uri.encodeComponent(objectPath);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encoded?alt=media';
  }
}
