import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Design-system color tokens.
///
/// This is a thin, discoverable facade over [AppTheme]'s palette — it does
/// not introduce new values. [AppTheme] remains the single source of truth
/// so existing call sites and [AppTheme.lightTheme] keep working unchanged.
abstract final class AppColors {
  static const Color navy = AppTheme.navy;
  static const Color navyDark = AppTheme.navyDark;
  static const Color navyLight = AppTheme.navyLight;
  static const Color teal = AppTheme.teal;
  static const Color tealLight = AppTheme.tealLight;
  static const Color emerald = AppTheme.emerald;
  static const Color emeraldLight = AppTheme.emeraldLight;
  static const Color amber = AppTheme.amber;
  static const Color amberLight = AppTheme.amberLight;
  static const Color amberDark = AppTheme.amberDark;

  static const Color primary = AppTheme.primaryColor;
  static const Color primaryLight = AppTheme.primaryLight;
  static const Color accent = AppTheme.accentColor;
  static const Color accentWarm = AppTheme.accentWarm;

  static const Color surface = AppTheme.surfaceColor;
  static const Color surfaceTint = AppTheme.surfaceTint;
  static const Color card = AppTheme.cardColor;

  static const Color textPrimary = AppTheme.textPrimary;
  static const Color textSecondary = AppTheme.textSecondary;
  static const Color border = AppTheme.borderColor;

  static const Color danger = AppTheme.danger;
  static const Color dangerSurface = AppTheme.dangerSurface;
  static const Color success = AppTheme.success;
}
