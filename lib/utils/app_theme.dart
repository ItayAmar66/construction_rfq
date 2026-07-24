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

/// Premium business theme — navy / blue / emerald / construction-amber (Hebrew RTL).
/// Palette matches the project-centric Claude Design source of truth.
class AppTheme {
  // Core palette
  static const Color navy = Color(0xFF0E2748);
  static const Color navyDark = Color(0xFF0A1D38);
  static const Color navyLight = Color(0xFF2E5C93);
  static const Color teal = Color(0xFF1E5AA8);
  static const Color tealLight = Color(0xFF3B7FC4);
  // Muted emerald matching the Bonim reference (was #059669 / #10B981).
  static const Color emerald = Color(0xFF1C7A49);
  static const Color emeraldLight = Color(0xFF2E7D57);
  static const Color amber = Color(0xFFE8912A);
  static const Color amberLight = Color(0xFFF0A94A);
  static const Color amberDark = Color(0xFFB4720A);

  static const Color primaryColor = navy;
  static const Color primaryLight = navyLight;
  static const Color accentColor = emerald;
  static const Color accentWarm = amber;
  // Neutral scale matching the reference (cooler, slightly warmer greys).
  static const Color surfaceColor = Color(0xFFF4F6FA);
  static const Color surfaceTint = Color(0xFFEEF1F6);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF141A24);
  static const Color textSecondary = Color(0xFF5C6B7F);
  static const Color borderColor = Color(0xFFE4E9F0);
  static const Color danger = Color(0xFFB23A2E);
  static const Color dangerSurface = Color(0xFFFCEDEC);
  static const Color success = emerald;

  // Status-surface tints (muted, reference-matched) — used by [AppStatusColors].
  static const Color greenSurface = Color(0xFFE4F3EA);
  static const Color greenMutedFg = Color(0xFF4A5A54);
  static const Color greenMutedSurface = Color(0xFFE9EEEB);
  static const Color amberSurface = Color(0xFFFBF0DC);
  static const Color blueSurface = Color(0xFFE8F0FB);
  static const Color redFg = Color(0xFF8A5252);

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
        shadowColor: _shadowColor.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
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
          textStyle: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
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
          textStyle: GoogleFonts.heebo(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.heebo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
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
      // Float snackbars above bottom nav/CTAs with a rounded, dismissible
      // surface so every message reads the same (the raw call sites that
      // don't go through the helpers pick this up automatically).
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      // Match dialogs to the app's card radius (16) instead of the M3
      // default 28, so modals sit in the same visual language as cards.
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    );

    final assistantTheme = GoogleFonts.assistantTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    final heeboTheme = GoogleFonts.heeboTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: assistantTheme.copyWith(
        displayLarge: heeboTheme.displayLarge
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w800),
        displayMedium: heeboTheme.displayMedium
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w800),
        displaySmall: heeboTheme.displaySmall
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: heeboTheme.headlineLarge
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: heeboTheme.headlineMedium
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        headlineSmall: heeboTheme.headlineSmall
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        titleLarge: heeboTheme.titleLarge
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: heeboTheme.titleMedium
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: heeboTheme.titleSmall
            ?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Soft, floating card shadow matching the reference (`0 8px 22px
  /// rgba(15,25,45,.07)` at `elevation: 2`, `0 6px 16px` at `elevation: 1`).
  static const Color _shadowColor = Color(0xFF0F192D);

  static BoxDecoration cardDecoration({
    Color? color,
    double elevation = 2,
  }) =>
      BoxDecoration(
        color: color ?? cardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: _shadowColor.withValues(alpha: 0.07),
            blurRadius: 10 + elevation * 6,
            offset: Offset(0, 4 + elevation * 2),
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

/// Muted, reference-matched status palette. Foreground hues follow the Bonim
/// prototype: blue = in-flight, amber = awaiting, green = positive, red =
/// negative, grey = neutral/closed.
class AppStatusColors {
  static (Color bg, Color fg, IconData? icon) forRequest(QuoteRequestStatus s) {
    switch (s) {
      case QuoteRequestStatus.draft:
        return (AppTheme.surfaceTint, AppTheme.textSecondary, Icons.edit_note_outlined);
      case QuoteRequestStatus.pendingApproval:
        return (AppTheme.amberSurface, AppTheme.amberDark, Icons.pending_actions_outlined);
      case QuoteRequestStatus.procurementApproved:
        return (AppTheme.greenSurface, AppTheme.emerald, Icons.approval_outlined);
      case QuoteRequestStatus.procurementRejected:
        return (AppTheme.dangerSurface, AppTheme.danger, Icons.cancel_outlined);
      case QuoteRequestStatus.sent:
        return (AppTheme.blueSurface, AppTheme.teal, Icons.send_outlined);
      case QuoteRequestStatus.quotesReceived:
        return (AppTheme.amberSurface, AppTheme.amberDark, Icons.mark_email_read_outlined);
      case QuoteRequestStatus.ordered:
        return (AppTheme.blueSurface, AppTheme.teal, Icons.receipt_long_outlined);
      case QuoteRequestStatus.shipped:
        return (AppTheme.greenSurface, AppTheme.emerald, Icons.local_shipping_outlined);
      case QuoteRequestStatus.pendingReceipt:
        return (AppTheme.amberSurface, AppTheme.amberDark, Icons.inventory_2_outlined);
      case QuoteRequestStatus.receivedFull:
        return (AppTheme.greenSurface, AppTheme.emerald, Icons.check_circle_outline);
      case QuoteRequestStatus.receivedWithIssues:
        return (AppTheme.dangerSurface, AppTheme.danger, Icons.report_problem_outlined);
      case QuoteRequestStatus.completed:
        return (AppTheme.greenMutedSurface, AppTheme.greenMutedFg, Icons.check_circle_outline);
      case QuoteRequestStatus.cancelled:
        return (AppTheme.dangerSurface, AppTheme.redFg, Icons.cancel_outlined);
      case QuoteRequestStatus.closed:
        return (AppTheme.surfaceTint, AppTheme.textSecondary, Icons.lock_outline);
    }
  }

  static (Color bg, Color fg) forQuote(String status) {
    switch (status) {
      case SupplierQuoteStatus.sent:
        return (AppTheme.blueSurface, AppTheme.teal);
      case SupplierQuoteStatus.approved:
        return (AppTheme.greenSurface, AppTheme.emerald);
      case SupplierQuoteStatus.rejected:
        return (AppTheme.dangerSurface, AppTheme.redFg);
      case SupplierQuoteStatus.shipped:
        return (AppTheme.blueSurface, AppTheme.teal);
      case SupplierQuoteStatus.notSelected:
        return (AppTheme.surfaceTint, AppTheme.textSecondary);
      case SupplierQuoteStatus.outdated:
        return (AppTheme.amberSurface, AppTheme.amberDark);
      default:
        return (AppTheme.surfaceTint, AppTheme.textSecondary);
    }
  }

  /// Project lifecycle colours (`fg`, `bg`) — absorbs the former
  /// `ProjectStatusChip` (rogue `Colors.orange` replaced with amber).
  static (Color fg, Color bg) forProject({
    required bool isDeletionPending,
    required bool isCompleted,
  }) {
    if (isDeletionPending) {
      return (AppTheme.amberDark, AppTheme.amberSurface);
    }
    if (isCompleted) {
      return (AppTheme.greenMutedFg, AppTheme.greenMutedSurface);
    }
    return (AppTheme.teal, AppTheme.teal.withValues(alpha: 0.12));
  }
}
