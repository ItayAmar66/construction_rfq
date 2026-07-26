import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../utils/crash_report_redaction.dart';
import 'crash_reporter.dart';

/// Forwards to Firebase Crashlytics. Not available on web (no Crashlytics
/// Flutter/web SDK) — [resolveCrashReporter] never selects this on web.
class CrashlyticsCrashReporter implements CrashReporter {
  CrashlyticsCrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    _crashlytics.recordError(
      error,
      stack,
      reason: reason == null ? null : CrashReportRedaction.redact(reason),
      fatal: fatal,
    );
  }

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    _crashlytics.recordFlutterError(details);
  }

  @override
  void setUser(String? id) {
    _crashlytics.setUserIdentifier(id ?? '');
  }

  @override
  void log(String message) {
    _crashlytics.log(CrashReportRedaction.redact(message));
  }
}

/// Pure selection rule (no Firebase calls) — kept separate so the on/off
/// logic is unit-testable without a Firebase test harness.
///
/// Crashlytics has no Flutter-web SDK, so web builds always stay on the
/// no-op reporter regardless of the feature flag.
bool shouldEnableCrashlytics({
  required bool crashReportingEnabled,
  required bool useFirebase,
  required bool isWeb,
}) {
  return crashReportingEnabled && useFirebase && !isWeb;
}

/// Builds the reporter to install, initializing Crashlytics only when
/// [shouldEnableCrashlytics] holds. Initialization failures never throw —
/// callers get [NoOpCrashReporter] back so crash-reporting setup can never
/// block app startup.
Future<CrashReporter> resolveCrashReporter({
  required bool crashReportingEnabled,
  required bool useFirebase,
  required bool isWeb,
}) async {
  if (!shouldEnableCrashlytics(
    crashReportingEnabled: crashReportingEnabled,
    useFirebase: useFirebase,
    isWeb: isWeb,
  )) {
    return const NoOpCrashReporter();
  }
  try {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    return CrashlyticsCrashReporter(crashlytics);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Crashlytics] init failed, staying on NoOp: $e');
    }
    return const NoOpCrashReporter();
  }
}
