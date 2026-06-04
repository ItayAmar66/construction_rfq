import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/quote_status.dart';
import '../utils/supplier_quote_status.dart';

/// Dashboard accent variants — single controlled palette.
enum DashboardAccent {
  navy,
  teal,
  emerald,
  amber,
}

extension DashboardAccentColors on DashboardAccent {
  Color get color {
    switch (this) {
      case DashboardAccent.navy:
        return AppTheme.navy;
      case DashboardAccent.teal:
        return AppTheme.teal;
      case DashboardAccent.emerald:
        return AppTheme.emerald;
      case DashboardAccent.amber:
        return AppTheme.amber;
    }
  }

  List<Color> get subtleGradient {
    switch (this) {
      case DashboardAccent.navy:
        return AppTheme.gradientNavy;
      case DashboardAccent.teal:
        return AppTheme.gradientTeal;
      case DashboardAccent.emerald:
        return AppTheme.gradientEmerald;
      case DashboardAccent.amber:
        return AppTheme.gradientAmber;
    }
  }
}

/// Premium business theme — navy / teal / emerald / amber (Hebrew RTL).
class AppTheme {
  // Core palette
  static const Color navy = Color(0xFF1E293B);
  static const Color navyDark = Color(0xFF0F172A);
  static const Color navyLight = Color(0xFF334155);
  static const Color teal = Color(0xFF0F766E);
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color emerald = Color(0xFF059669);
  static const Color emeraldLight = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFF59E0B);

  static const Color primaryColor = navy;
  static const Color primaryLight = navyLight;
  static const Color accentColor = emerald;
  static const Color accentWarm = amber;
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color surfaceTint = Color(0xFFF1F5F9);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color success = emerald;

  static const double radiusSm = 10;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static const List<Color> gradientNavy = [navyDark, navy];
  static const List<Color> gradientTeal = [Color(0xFF0D5C56), teal];
  static const List<Color> gradientEmerald = [Color(0xFF047857), emerald];
  static const List<Color> gradientAmber = [Color(0xFFB45309), amber];
  static const List<Color> gradientHero = [navyDark, Color(0xFF1E3A4F), teal];

  // Legacy aliases (same family — avoid rainbow elsewhere)
  static const List<Color> gradientPrimary = gradientNavy;
  static const List<Color> gradientBlue = gradientNavy;
  static const List<Color> gradientPurple = gradientNavy;
  static const List<Color> gradientRose = gradientTeal;
  static const List<Color> gradientCyan = gradientTeal;
  static const List<Color> gradientRevenue = gradientNavy;
  static const Color accentBlue = navy;
  static const Color accentPurple = navyLight;
  static const Color accentRevenue = navyDark;
  static const Color accentRose = teal;
  static const Color accentTeal = teal;

  static LinearGradient linearGradient(
    List<Color> colors, {
    AlignmentGeometry begin = Alignment.topRight,
    AlignmentGeometry end = Alignment.bottomLeft,
  }) =>
      LinearGradient(colors: colors, begin: begin, end: end);

  static ThemeData lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: teal,
        tertiary: emerald,
        surface: surfaceColor,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: surfaceColor,
      dividerColor: borderColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1,
        shadowColor: navy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 1,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: borderColor),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.rubik(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        elevation: 8,
        shadowColor: navy.withValues(alpha: 0.1),
        height: 64,
        indicatorColor: teal.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? navy : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? navy : textSecondary,
            size: 22,
          );
        }),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.rubikTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  static BoxDecoration cardDecoration({
    Color? color,
    double elevation = 2,
  }) =>
      BoxDecoration(
        color: color ?? cardColor,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: borderColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.06),
            blurRadius: elevation * 3,
            offset: Offset(0, elevation),
          ),
        ],
      );

  static BoxDecoration gradientCardDecoration({
    required List<Color> colors,
    double radius = radiusMd,
  }) =>
      BoxDecoration(
        gradient: linearGradient(colors),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

class AppStatusColors {
  static (Color bg, Color fg, IconData? icon) forRequest(QuoteRequestStatus s) {
    switch (s) {
      case QuoteRequestStatus.draft:
        return (AppTheme.surfaceTint, AppTheme.textSecondary, Icons.edit_note_outlined);
      case QuoteRequestStatus.sent:
        return (const Color(0xFFE0F2FE), AppTheme.navy, Icons.send_outlined);
      case QuoteRequestStatus.quotesReceived:
        return (const Color(0xFFD1FAE5), AppTheme.emerald, Icons.mark_email_read_outlined);
      case QuoteRequestStatus.ordered:
        return (const Color(0xFFCCFBF1), AppTheme.teal, Icons.receipt_long_outlined);
      case QuoteRequestStatus.shipped:
        return (const Color(0xFFECFDF5), AppTheme.emerald, Icons.local_shipping_outlined);
      case QuoteRequestStatus.completed:
        return (const Color(0xFFD1FAE5), AppTheme.emerald, Icons.check_circle_outline);
      case QuoteRequestStatus.cancelled:
        return (const Color(0xFFFEF3C7), AppTheme.amber, Icons.cancel_outlined);
      case QuoteRequestStatus.closed:
        return (AppTheme.surfaceTint, AppTheme.navyLight, Icons.lock_outline);
    }
  }

  static (Color bg, Color fg) forQuote(String status) {
    switch (status) {
      case SupplierQuoteStatus.sent:
        return (const Color(0xFFE0F2FE), AppTheme.navy);
      case SupplierQuoteStatus.approved:
        return (const Color(0xFFD1FAE5), AppTheme.emerald);
      case SupplierQuoteStatus.rejected:
        return (const Color(0xFFFEF3C7), AppTheme.amber);
      case SupplierQuoteStatus.shipped:
        return (const Color(0xFFCCFBF1), AppTheme.teal);
      case SupplierQuoteStatus.notSelected:
        return (AppTheme.surfaceTint, AppTheme.textSecondary);
      case SupplierQuoteStatus.outdated:
        return (const Color(0xFFFEF3C7), AppTheme.amber);
      default:
        return (AppTheme.surfaceTint, AppTheme.textSecondary);
    }
  }
}
