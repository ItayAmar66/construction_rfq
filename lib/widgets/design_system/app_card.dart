import 'package:flutter/material.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';

/// Generic container card — applies `AppTheme.cardDecoration()` (the same
/// decoration already used ad hoc by [AppListCard], [V2StatCard],
/// [LoadingView], etc.) so any content can sit in a consistent card without
/// each screen re-declaring the decoration by hand.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.color,
    this.elevation = 2,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final decoration = AppTheme.cardDecoration(color: color, elevation: elevation);

    if (onTap == null) {
      return Container(decoration: decoration, child: content);
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: content,
        ),
      ),
    );
  }
}
