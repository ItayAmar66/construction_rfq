import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Controls Firebase vs local demo backend.
class AppMode {
  AppMode._();

  static bool isDemoMode = false;
  static bool isFirebaseInitialized = false;
  static String? statusMessage;

  /// Demo presentation UI (banner, scenarios, debug login) — debug builds only.
  static bool get showDemoPresentation => kDebugMode && isDemoMode;

  /// True when Firebase should be used (initialized and not in explicit demo).
  static bool get useFirebase => isFirebaseInitialized && !isDemoMode;

  static bool get isFirebaseConfigured {
    final options = DefaultFirebaseOptions.currentPlatform;
    return !options.apiKey.contains('YOUR_') &&
        !options.projectId.contains('YOUR_');
  }

  static Future<void> initialize() async {
    if (!isFirebaseConfigured) {
      enableDemoMode('מצב הדגמה — Firebase לא הוגדר');
      if (kDebugMode) {
        debugPrint('[AppMode] Firebase not configured — demo mode');
      }
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseInitialized = true;
      isDemoMode = false;
      if (kDebugMode) {
        debugPrint('[AppMode] Firebase initialized: ${DefaultFirebaseOptions.currentPlatform.projectId}');
      }
    } catch (e, st) {
      enableDemoMode('מצב הדגמה — לא ניתן להתחבר ל-Firebase');
      if (kDebugMode) {
        debugPrint('[AppMode] Firebase init failed: $e\n$st');
      }
    }
  }

  /// Explicit demo only (demo login buttons). Never auto-switch when Firebase works.
  static void enableDemoMode([String? message]) {
    isDemoMode = true;
    statusMessage = message ?? 'מצב הדגמה — נתונים מקומיים';
    if (kDebugMode) {
      debugPrint('[AppMode] Demo mode enabled: $statusMessage');
    }
  }

  /// Do NOT call when Firebase is configured — keeps shared Firestore as source of truth.
  static void tryFallbackToDemo(Object error) {
    if (useFirebase) {
      if (kDebugMode) {
        debugPrint('[AppMode] Firestore/Auth error (staying on Firebase): $error');
      }
      return;
    }
    if (FirebaseErrorHelper.isUnavailable(error)) {
      enableDemoMode('מצב הדגמה — השרת לא זמין');
    }
  }
}

/// Maps Firebase / network errors to Hebrew messages.
class FirebaseErrorHelper {
  static bool isUnavailable(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unavailable') ||
        message.contains('offline') ||
        message.contains('failed host lookup') ||
        message.contains('network') ||
        message.contains('connection');
  }

  static String toHebrewMessage(Object error) {
    if (isUnavailable(error)) {
      return 'אין חיבור לשרת. בדוק את החיבור לאינטרנט.';
    }
    if (error.toString().contains('permission-denied')) {
      return 'אין הרשאה לגשת לנתונים. בדוק את כללי Firestore.';
    }
    return 'אירעה שגיאה בטעינת הנתונים. נסה שוב מאוחר יותר.';
  }
}
