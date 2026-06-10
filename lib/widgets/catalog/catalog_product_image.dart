import 'package:flutter/material.dart';

import '../../models/catalog/catalog_search_hit.dart';
import '../../utils/app_theme.dart';
import '../../utils/catalog_image_url.dart';

/// Catalog thumbnail/detail image — shared resolver for card and detail sheet.
class CatalogProductImage extends StatelessWidget {
  const CatalogProductImage({
    super.key,
    required this.hit,
    this.fit = BoxFit.cover,
    this.placeholderIconSize = 28,
  });

  final CatalogSearchHit hit;
  final BoxFit fit;
  final double placeholderIconSize;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: CatalogImageUrl.resolveHitImageAsync(hit),
      builder: (context, snapshot) {
        final url = snapshot.data ?? CatalogImageUrl.resolveHitImage(hit);
        if (url == null || url.isEmpty) {
          return _Placeholder(iconSize: placeholderIconSize);
        }
        return Image.network(
          url,
          fit: fit,
          errorBuilder: (_, __, ___) => _Placeholder(iconSize: placeholderIconSize),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.textSecondary,
        size: iconSize,
      ),
    );
  }
}
