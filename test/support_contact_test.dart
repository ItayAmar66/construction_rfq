import 'package:construction_rfq/analytics/app_analytics.dart';
import 'package:construction_rfq/utils/support_contact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAnalytics implements AppAnalytics {
  final events = <String>[];

  @override
  void track(String name, [Map<String, Object?>? params]) => events.add(name);
}

void main() {
  testWidgets('openSupportContact tracks support_opened and never throws',
      (tester) async {
    final analytics = _RecordingAnalytics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appAnalyticsProvider.overrideWithValue(analytics)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () => openSupportContact(context, ref, route: '/test'),
                child: const Text('open support'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open support'));
    // No real platform channel for url_launcher/clipboard in a unit test —
    // this exercises the fallback path without letting a
    // MissingPluginException escape as an unhandled error.
    await tester.pump(const Duration(milliseconds: 300));

    expect(analytics.events, [AppAnalyticsEvents.supportOpened]);
  });
}
