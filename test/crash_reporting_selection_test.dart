import 'package:construction_rfq/services/crash_reporter.dart';
import 'package:construction_rfq/services/crashlytics_crash_reporter.dart';
import 'package:construction_rfq/utils/crash_report_redaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldEnableCrashlytics', () {
    test('off when the feature flag is disabled', () {
      expect(
        shouldEnableCrashlytics(
          crashReportingEnabled: false,
          useFirebase: true,
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('off in demo mode (useFirebase false)', () {
      expect(
        shouldEnableCrashlytics(
          crashReportingEnabled: true,
          useFirebase: false,
          isWeb: false,
        ),
        isFalse,
      );
    });

    test('off on web even when flag + Firebase are on (no web Crashlytics SDK)',
        () {
      expect(
        shouldEnableCrashlytics(
          crashReportingEnabled: true,
          useFirebase: true,
          isWeb: true,
        ),
        isFalse,
      );
    });

    test('on for a native, non-demo build with the flag enabled', () {
      expect(
        shouldEnableCrashlytics(
          crashReportingEnabled: true,
          useFirebase: true,
          isWeb: false,
        ),
        isTrue,
      );
    });
  });

  group('resolveCrashReporter', () {
    test('returns NoOpCrashReporter when disabled, without touching Firebase',
        () async {
      final reporter = await resolveCrashReporter(
        crashReportingEnabled: false,
        useFirebase: true,
        isWeb: false,
      );
      expect(reporter, isA<NoOpCrashReporter>());
    });

    test('returns NoOpCrashReporter on web regardless of the flag', () async {
      final reporter = await resolveCrashReporter(
        crashReportingEnabled: true,
        useFirebase: true,
        isWeb: true,
      );
      expect(reporter, isA<NoOpCrashReporter>());
    });
  });

  group('CrashReportRedaction', () {
    test('masks email addresses', () {
      expect(
        CrashReportRedaction.redact('failed for user a@b.com during sync'),
        'failed for user [email] during sync',
      );
    });

    test('masks long opaque tokens (ids, auth tokens)', () {
      final redacted = CrashReportRedaction.redact(
        'invite accept failed for token abcdEF1234567890ghijKLmn',
      );
      expect(redacted, contains('[redacted]'));
      expect(redacted, isNot(contains('abcdEF1234567890ghijKLmn')));
    });

    test('leaves short, non-sensitive labels untouched', () {
      expect(
        CrashReportRedaction.redact('quote_service submitTenderCounterBid'),
        'quote_service submitTenderCounterBid',
      );
    });
  });

  group('NoOpCrashReporter', () {
    test('every method is a safe no-op', () {
      const reporter = NoOpCrashReporter();
      expect(
        () => reporter.recordError(Exception('x'), StackTrace.current),
        returnsNormally,
      );
      expect(
        () => reporter.recordFlutterError(
          FlutterErrorDetails(exception: Exception('x')),
        ),
        returnsNormally,
      );
      expect(() => reporter.setUser('uid'), returnsNormally);
      expect(() => reporter.log('breadcrumb'), returnsNormally);
    });
  });
}
