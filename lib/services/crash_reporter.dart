import 'package:flutter/foundation.dart';

/// Abstraction over a crash / error reporting backend (Crashlytics, Sentry, …).
///
/// The default [NoOpCrashReporter] does nothing, so production behaviour is
/// unchanged until a real reporter is wired. To enable reporting, assign
/// [CrashReporter.instance] once during bootstrap, before `runApp`:
///
/// ```dart
/// CrashReporter.instance = MyCrashlyticsReporter();
/// ```
///
/// The single choke point that feeds this is
/// `BootstrapErrorHandling.install()` (Flutter + platform errors) and
/// [AppLogger] (logged errors).
abstract interface class CrashReporter {
  /// The active reporter. Defaults to a no-op so nothing is sent until wired.
  static CrashReporter instance = const NoOpCrashReporter();

  /// Report a non-fatal or fatal error with an optional stack trace.
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal,
  });

  /// Report a Flutter framework error.
  void recordFlutterError(FlutterErrorDetails details);

  /// Attach a stable, non-PII identifier for the current session.
  void setUser(String? id);

  /// Add a breadcrumb for later crash context.
  void log(String message);
}

/// Default reporter that discards everything. Safe in every build.
class NoOpCrashReporter implements CrashReporter {
  const NoOpCrashReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void recordFlutterError(FlutterErrorDetails details) {}

  @override
  void setUser(String? id) {}

  @override
  void log(String message) {}
}
