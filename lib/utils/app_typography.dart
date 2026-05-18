import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Rubik text styles — use instead of ad-hoc TextStyle.
abstract final class AppTypography {
  static TextStyle display(BuildContext context) =>
      _base(context, 22, FontWeight.w700);

  static TextStyle h1(BuildContext context) =>
      _base(context, 18, FontWeight.w600);

  static TextStyle h2(BuildContext context) =>
      _base(context, 16, FontWeight.w600);

  static TextStyle body(BuildContext context) =>
      _base(context, 14, FontWeight.w500);

  static TextStyle bodySecondary(BuildContext context) =>
      _base(context, 14, FontWeight.w400, color: AppTheme.textSecondary);

  static TextStyle caption(BuildContext context) =>
      _base(context, 12, FontWeight.w500, color: AppTheme.textSecondary);

  static TextStyle micro(BuildContext context) =>
      _base(context, 11, FontWeight.w600, color: AppTheme.textSecondary);

  static TextStyle kpiValue(BuildContext context) =>
      _base(context, 20, FontWeight.w700);

  static TextStyle kpiLabel(BuildContext context) =>
      _base(context, 12, FontWeight.w500, color: AppTheme.textSecondary);

  static TextStyle _base(
    BuildContext context,
    double size,
    FontWeight weight, {
    Color? color,
  }) {
    return GoogleFonts.rubik(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppTheme.textPrimary,
      height: 1.2,
    );
  }
}
