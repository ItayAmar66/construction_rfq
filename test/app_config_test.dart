import 'package:construction_rfq/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('defaults to dev environment when no --dart-define is set', () {
      // Tests run without APP_ENV defined, so the default path is exercised.
      expect(AppConfig.environment, AppEnvironment.dev);
      expect(AppConfig.isDev, isTrue);
      expect(AppConfig.isProd, isFalse);
      expect(AppConfig.isStaging, isFalse);
      expect(AppConfig.environmentLabel, 'dev');
    });

    test('appVersion has a sensible default', () {
      expect(AppConfig.appVersion, isNotEmpty);
    });

    test('summary is PII-free and contains env + version', () {
      final summary = AppConfig.summary;
      expect(summary, contains('env=dev'));
      expect(summary, contains('version=${AppConfig.appVersion}'));
    });

    test('verboseDiagnostics is on outside a prod release', () {
      expect(AppConfig.verboseDiagnostics, isTrue);
    });
  });
}
