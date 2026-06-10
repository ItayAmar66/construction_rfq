import 'package:flutter/material.dart';

import '../models/catalog/catalog_search_hit.dart';
import 'catalog_image_url.dart';

/// Prefetch first-page catalog thumbnails into Flutter image cache.
abstract final class CatalogImagePrefetch {
  static const defaultLimit = 24;

  static void prefetchHits(
    BuildContext context,
    List<CatalogSearchHit> hits, {
    int limit = defaultLimit,
  }) {
    if (hits.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      var count = 0;
      for (final hit in hits) {
        if (count >= limit) break;
        final url = CatalogImageUrl.resolveHitImage(hit);
        if (url == null || url.isEmpty) continue;
        count++;
        precacheImage(
          NetworkImage(url),
          context,
        ).catchError((_) {});
      }
    });
  }
}
