import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import 'hebrew_strings.dart';

/// User-facing catalog search / selector error copy.
abstract final class CatalogSearchErrorHelper {
  static String headline(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    if (text.contains('permission-denied')) {
      return 'אין הרשאה לקרוא את הקטלוג מהשרת';
    }
    if (text.contains('failed-precondition') || text.contains('index')) {
      return 'חסר אינדקס חיפוש בקטלוג — נדרש deploy של indexes';
    }
    if (FirebaseErrorHelper.isUnavailable(error ?? '')) {
      return 'אין חיבור לשרת הקטלוג';
    }
    if (text.contains('not found') || text.isEmpty) {
      return HebrewStrings.errorCatalogNotLoaded;
    }
    return HebrewStrings.errorCatalogSearchUnavailable;
  }

  static String hint({required bool showDebug}) {
    final base = HebrewStrings.catalogSearchErrorHint;
    if (!showDebug || !kDebugMode) return base;
    return '$base\n${HebrewStrings.catalogSearchDebugHint}';
  }

  static bool shouldShowDebugHint(Object? error) {
    if (!kDebugMode) return false;
    final text = error?.toString().toLowerCase() ?? '';
    return text.contains('permission-denied') ||
        text.contains('failed-precondition') ||
        text.contains('index') ||
        AppMode.useFirebase;
  }
}
