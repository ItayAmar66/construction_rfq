import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/catalog/catalog_search_hit.dart';
import '../../utils/app_theme.dart';
import '../../utils/catalog_image_url.dart';

/// Catalog thumbnail/detail image — shared fast resolver for card and detail sheet.
class CatalogProductImage extends StatefulWidget {
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
  State<CatalogProductImage> createState() => _CatalogProductImageState();
}

class _CatalogProductImageState extends State<CatalogProductImage> {
  late String? _url;
  bool _triedTokenFallback = false;

  @override
  void initState() {
    super.initState();
    _url = CatalogImageUrl.resolveHitImage(widget.hit);
  }

  @override
  void didUpdateWidget(CatalogProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hit.variant.id != widget.hit.variant.id ||
        oldWidget.hit.product?.id != widget.hit.product?.id) {
      _url = CatalogImageUrl.resolveHitImage(widget.hit);
      _triedTokenFallback = false;
    }
  }

  Future<void> _retryWithTokenUrl() async {
    if (_triedTokenFallback) return;
    _triedTokenFallback = true;
    final tokenUrl = await CatalogImageUrl.tokenUrlForHit(widget.hit);
    if (!mounted || tokenUrl == null || tokenUrl == _url) return;
    setState(() => _url = tokenUrl);
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) {
      return _Placeholder(iconSize: widget.placeholderIconSize);
    }

    return Image.network(
      url,
      key: ValueKey(url),
      fit: widget.fit,
      gaplessPlayback: true,
      webHtmlElementStrategy: catalogImageWebHtmlElementStrategy,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _LoadingSkeleton(iconSize: widget.placeholderIconSize);
      },
      errorBuilder: (_, __, ___) {
        _retryWithTokenUrl();
        return _Placeholder(iconSize: widget.placeholderIconSize);
      },
    );
  }
}

/// Web uses HTML <img> to avoid NetworkImageLoadException (statusCode: 0 / CORS).
@visibleForTesting
WebHtmlElementStrategy get catalogImageWebHtmlElementStrategy =>
    kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never;

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surfaceTint,
      child: Center(
        child: SizedBox(
          width: iconSize * 0.6,
          height: iconSize * 0.6,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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
