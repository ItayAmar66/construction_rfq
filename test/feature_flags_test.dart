import 'package:construction_rfq/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlags', () {
    test('production-risky flags default OFF', () {
      final flags = FeatureFlags.fromEnvironment();
      // Analytics and crash reporting stay off until explicitly enabled per
      // build, so no data leaves the device without an opt-in --dart-define.
      expect(flags.analyticsEnabled, isFalse);
      expect(flags.crashReportingEnabled, isFalse);
    });

    test('demo login is available in non-prod builds by default', () {
      // Tests run with APP_ENV unset (dev), so demo login defaults on.
      final flags = FeatureFlags.fromEnvironment();
      expect(flags.demoLoginEnabled, isTrue);
    });

    test('copyWith overrides only the given fields', () {
      const base = FeatureFlags(
        analyticsEnabled: false,
        crashReportingEnabled: false,
        demoLoginEnabled: false,
      );
      final updated = base.copyWith(analyticsEnabled: true);
      expect(updated.analyticsEnabled, isTrue);
      expect(updated.crashReportingEnabled, isFalse);
      expect(updated.demoLoginEnabled, isFalse);
    });
  });
}
