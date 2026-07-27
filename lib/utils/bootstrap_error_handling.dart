import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../services/crash_reporter.dart';
import 'app_theme.dart';

/// App-wide bootstrap/runtime error hooks so release web does not grey-screen.
///
/// This is the single choke point for uncaught errors. Both handlers forward to
/// [CrashReporter.instance] (a no-op by default), so wiring a real crash
/// reporter in production is a one-line change with no edits here.
abstract final class BootstrapErrorHandling {
  static const bootstrapErrorTitle = 'משהו השתבש במסך הזה';
  static const bootstrapErrorBody =
      'החלק הזה של המסך נתקל בתקלה. אפשר לנסות שוב או לחזור למסך הבית — שאר החשבון שלך תקין.';

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

    ErrorWidget.builder = (details) => _AppErrorScreen(details: details);
  }
}

/// Recoverable, on-brand replacement for Flutter's default red/black crash
/// screen. Rendered for any uncaught widget-build exception; always offers a
/// way out (retry the current screen or go home) instead of a dead end.
class _AppErrorScreen extends StatelessWidget {
  const _AppErrorScreen({required this.details});

  final FlutterErrorDetails details;

  void _retry(BuildContext context) {
    final navContext = appRootNavigatorKey.currentContext;
    if (navContext == null) return;
    final router = GoRouter.maybeOf(navContext);
    if (router == null) return;
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    router.go(location);
  }

  void _goHome(BuildContext context) {
    final navContext = appRootNavigatorKey.currentContext;
    if (navContext == null) return;
    GoRouter.maybeOf(navContext)?.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppTheme.danger,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  BootstrapErrorHandling.bootstrapErrorTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  BootstrapErrorHandling.bootstrapErrorBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _goHome(context),
                      icon: const Icon(Icons.home_outlined, size: 18),
                      label: const Text('חזרה לדף הבית'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.navy,
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _retry(context),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('נסה שוב'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navy,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Coalesce rapid notifier updates to avoid reentrant listener iteration.
void scheduleRouterRefresh(VoidCallback refresh) {
  scheduleMicrotask(refresh);
}
