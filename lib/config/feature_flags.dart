import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Build-time feature flags.
///
/// Each flag reads a `--dart-define` with a safe default, so features can be
/// toggled per build/environment without code changes. This is a compile-time
/// scaffold: swap [featureFlagsProvider] for a Remote Config-backed
/// implementation to gain runtime kill-switches without shipping a new release.
///
/// Example:
/// ```sh
/// flutter build web --dart-define=FEATURE_ANALYTICS=true
/// ```
@immutable
class FeatureFlags {
  const FeatureFlags({
    required this.analyticsEnabled,
    required this.crashReportingEnabled,
    required this.demoLoginEnabled,
  });

  /// Send product analytics events to the configured sink.
  final bool analyticsEnabled;

  /// Forward uncaught errors to the configured crash reporter.
  final bool crashReportingEnabled;

  /// Show demo / quick-login affordances (developer convenience).
  final bool demoLoginEnabled;

  /// Flags resolved from `--dart-define` at build time.
  factory FeatureFlags.fromEnvironment() {
    // `*.fromEnvironment` must be evaluated in a const context to read the
    // compile-time define, hence the `const` locals below.
    const analytics = bool.fromEnvironment('FEATURE_ANALYTICS');
    const crashReporting = bool.fromEnvironment('FEATURE_CRASH_REPORTING');
    const demoLogin =
        bool.fromEnvironment('FEATURE_DEMO_LOGIN', defaultValue: true);
    return FeatureFlags(
      analyticsEnabled: analytics,
      crashReportingEnabled: crashReporting,
      // Demo login is never available in a prod build, even if the define is on.
      demoLoginEnabled: demoLogin && !AppConfig.isProd,
    );
  }

  FeatureFlags copyWith({
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? demoLoginEnabled,
  }) {
    return FeatureFlags(
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      demoLoginEnabled: demoLoginEnabled ?? this.demoLoginEnabled,
    );
  }

  @override
  String toString() => 'FeatureFlags(analytics=$analyticsEnabled, '
      'crashReporting=$crashReportingEnabled, demoLogin=$demoLoginEnabled)';
}

/// App-wide feature flags. Override in tests or wire to Remote Config here.
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags.fromEnvironment(),
);
