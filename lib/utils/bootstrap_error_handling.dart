import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/crash_reporter.dart';

/// App-wide bootstrap/runtime error hooks so release web does not grey-screen.
///
/// This is the single choke point for uncaught errors. Both handlers forward to
/// [CrashReporter.instance] (a no-op by default), so wiring a real crash
/// reporter in production is a one-line change with no edits here.
abstract final class BootstrapErrorHandling {
  static const bootstrapErrorTitle = 'אירעה שגיאה בטעינת המערכת';
  static const bootstrapErrorBody =
      'נסה לרענן את הדף או התחבר מחדש.';

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      CrashReporter.instance.recordFlutterError(details);
      if (kDebugMode) {
        debugPrint('[BootstrapError] ${details.exceptionAsString()}');
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      CrashReporter.instance.recordError(error, stack, fatal: true);
      if (kDebugMode) {
        debugPrint('[BootstrapError] $error\n$stack');
      }
      return true;
    };

    ErrorWidget.builder = (details) {
      return Material(
        color: const Color(0xFF1A1A1A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                const SizedBox(height: 16),
                Text(
                  bootstrapErrorTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  bootstrapErrorBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    };
  }
}

/// Coalesce rapid notifier updates to avoid reentrant listener iteration.
void scheduleRouterRefresh(VoidCallback refresh) {
  scheduleMicrotask(refresh);
}
