import 'package:construction_rfq/analytics/app_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAnalytics implements AppAnalytics {
  final events = <MapEntry<String, Map<String, Object?>?>>[];

  @override
  void track(String name, [Map<String, Object?>? params]) {
    events.add(MapEntry(name, params));
  }
}

void main() {
  group('shouldEnableFirebaseAnalytics', () {
    test('off when the flag is disabled', () {
      expect(
        shouldEnableFirebaseAnalytics(analyticsEnabled: false, useFirebase: true),
        isFalse,
      );
    });

    test('off in demo mode (useFirebase false)', () {
      expect(
        shouldEnableFirebaseAnalytics(analyticsEnabled: true, useFirebase: false),
        isFalse,
      );
    });

    test('on for a real (non-demo) session with the flag enabled', () {
      expect(
        shouldEnableFirebaseAnalytics(analyticsEnabled: true, useFirebase: true),
        isTrue,
      );
    });
  });

  group('resolveAppAnalytics', () {
    test('returns a non-Firebase sink when disabled, without touching Firebase',
        () async {
      final analytics = await resolveAppAnalytics(
        analyticsEnabled: false,
        useFirebase: true,
      );
      expect(analytics, isNot(isA<FirebaseAppAnalytics>()));
    });

    test('returns a non-Firebase sink in demo mode', () async {
      final analytics = await resolveAppAnalytics(
        analyticsEnabled: true,
        useFirebase: false,
      );
      expect(analytics, isNot(isA<FirebaseAppAnalytics>()));
    });
  });

  group('NoOpAppAnalytics / DebugAppAnalytics', () {
    test('never throw regardless of params', () {
      const noop = NoOpAppAnalytics();
      const debug = DebugAppAnalytics();
      expect(() => noop.track('x', {'a': 1}), returnsNormally);
      expect(() => debug.track('x', {'a': 1}), returnsNormally);
      expect(() => noop.track('x'), returnsNormally);
    });
  });

  group('AppAnalyticsEvents', () {
    test('funnel event names are all distinct', () {
      final names = {
        AppAnalyticsEvents.registrationStarted,
        AppAnalyticsEvents.registrationCompleted,
        AppAnalyticsEvents.emailVerificationCompleted,
        AppAnalyticsEvents.invitationOpened,
        AppAnalyticsEvents.invitationAccepted,
        AppAnalyticsEvents.invitationFailed,
        AppAnalyticsEvents.projectCreated,
        AppAnalyticsEvents.rfqDraftStarted,
        AppAnalyticsEvents.rfqSent,
        AppAnalyticsEvents.supplierViewedRfq,
        AppAnalyticsEvents.quoteSubmitted,
        AppAnalyticsEvents.quoteApproved,
        AppAnalyticsEvents.quoteRejected,
        AppAnalyticsEvents.orderShipped,
        AppAnalyticsEvents.deliveryConfirmed,
        AppAnalyticsEvents.supportOpened,
      };
      expect(names, hasLength(16));
    });
  });

  group('event recording (no duplicate/no-op sink swap)', () {
    test('a recording sink captures exactly the events tracked', () {
      final analytics = _RecordingAnalytics();
      analytics.track(AppAnalyticsEvents.rfqSent, {'invited_supplier_count': 2});
      analytics.track(AppAnalyticsEvents.quoteSubmitted, {'is_tender': false});

      expect(analytics.events, hasLength(2));
      expect(analytics.events[0].key, AppAnalyticsEvents.rfqSent);
      expect(analytics.events[0].value, {'invited_supplier_count': 2});
      expect(analytics.events[1].key, AppAnalyticsEvents.quoteSubmitted);
    });
  });
}
