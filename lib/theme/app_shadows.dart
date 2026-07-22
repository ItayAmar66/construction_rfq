import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Elevation tokens matching the shadow already produced by
/// [AppTheme.cardDecoration] and [StatusChip]-style pills, so new widgets
/// built with [AppShadows] look identical to existing cards/chips.
abstract final class AppShadows {
  /// Same shadow as `AppTheme.cardDecoration(elevation: 1)`.
  static List<BoxShadow> card({double elevation = 2}) => [
        BoxShadow(
          color: AppTheme.navy.withValues(alpha: 0.06),
          blurRadius: elevation * 3,
          offset: Offset(0, elevation),
        ),
      ];

  /// Soft tinted shadow used by pill/chip-style widgets.
  static List<BoxShadow> pill(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.12),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Stronger shadow for gradient hero cards, matching
  /// `AppTheme.gradientCardDecoration`.
  static List<BoxShadow> gradient(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}
