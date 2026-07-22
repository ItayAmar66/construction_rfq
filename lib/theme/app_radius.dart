import '../utils/app_theme.dart';

/// Corner-radius tokens — mirrors [AppTheme]'s existing radii so shapes stay
/// consistent with every widget already built on `AppTheme.radiusSm/Md/Lg`.
abstract final class AppRadius {
  static const double sm = AppTheme.radiusSm;
  static const double md = AppTheme.radiusMd;
  static const double lg = AppTheme.radiusLg;

  /// Fully rounded — chips, pills, avatar badges.
  static const double pill = 999;
}
