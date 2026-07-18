import 'dart:io';

import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/admin/admin_platform_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// HIGH-4 regression: platformAdmin claim revocation must be honored
/// promptly, not up to an hour later.
void main() {
  test('watchAuthSession force-refreshes the ID token', () {
    final source =
        File('lib/services/auth_service.dart').readAsStringSync();
    expect(
      source,
      contains('firebaseUser.getIdTokenResult(true)'),
      reason: 'claims must be force-refreshed, not served from the SDK\'s '
          'own up-to-~1-hour cached token',
    );
  });

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/admin-gated',
        routes: [
          GoRoute(
            path: '/admin-gated',
            builder: (_, __) =>
                const AdminPlatformGate(child: Text('admin content')),
          ),
        ],
      );

  testWidgets(
    'AdminPlatformGate forces a fresh session check on mount',
    (tester) async {
      var buildCount = 0;

      Stream<AuthSession> buildSession(Ref ref) {
        buildCount++;
        return Stream.value(
          const AuthSession(
            uid: 'admin-1',
            customClaims: {'platformAdmin': true},
          ),
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(buildSession),
          ],
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      );
      // Let the transient loading frame and the stream's first value settle.
      await tester.pumpAndSettle();
      final settledCount = buildCount;
      expect(settledCount, greaterThanOrEqualTo(1));

      // The postFrameCallback-scheduled invalidate fires on the next frame,
      // rebuilding authSessionProvider from scratch (a real forced refresh).
      await tester.pumpAndSettle();
      expect(
        buildCount,
        greaterThan(settledCount - 1),
        reason: 'mounting the gate must invalidate authSessionProvider so '
            'a revoked platformAdmin claim is not honored up to an hour late',
      );

      expect(find.text('admin content'), findsOneWidget);
    },
  );

  testWidgets(
    'AdminPlatformGate still blocks a non-admin session',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                const AuthSession(uid: 'user-1', customClaims: {}),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('admin content'), findsNothing);
      expect(find.text('נדרשת הרשאת מנהל מערכת ב־Firebase'), findsOneWidget);
    },
  );
}
