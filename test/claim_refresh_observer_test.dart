import 'dart:async';

import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/admin/admin_platform_gate.dart';
import 'package:construction_rfq/widgets/claim_refresh_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Custom-claim refresh must not depend on the SDK's own up-to-~1-hour
/// token cache: it should react to idToken change events, foreground
/// resume, and a periodic fallback, without looping on itself.
void main() {
  /// A trivial consumer that keeps authSessionProvider alive/watched, the
  /// same way the real app always has something watching it (the router,
  /// AdminPlatformGate, etc.) — otherwise Riverpod never builds the
  /// provider in the first place and there's nothing to invalidate.
  Widget watchingChild() => Consumer(
        builder: (context, ref, _) {
          ref.watch(authSessionProvider);
          return const SizedBox();
        },
      );

  testWidgets(
    'foreground resume forces a fresh authSessionProvider build',
    (tester) async {
      var buildCount = 0;
      Stream<AuthSession> buildSession(Ref ref) {
        buildCount++;
        return Stream.value(
          const AuthSession(uid: 'u1', customClaims: {}),
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authSessionProvider.overrideWith(buildSession)],
          child: MaterialApp(
            home: ClaimRefreshObserver(child: watchingChild()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = buildCount;

      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(before));

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'periodic timer forces a fresh authSessionProvider build',
    (tester) async {
      var buildCount = 0;
      Stream<AuthSession> buildSession(Ref ref) {
        buildCount++;
        return Stream.value(
          const AuthSession(uid: 'u1', customClaims: {}),
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authSessionProvider.overrideWith(buildSession)],
          child: MaterialApp(
            home: ClaimRefreshObserver(
              periodicInterval: const Duration(seconds: 5),
              child: watchingChild(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = buildCount;

      await tester.pump(const Duration(seconds: 5, milliseconds: 50));
      await tester.pumpAndSettle();

      expect(buildCount, greaterThan(before));

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'idToken change tick forces a refresh, but a rapid repeat is debounced',
    (tester) async {
      var buildCount = 0;
      Stream<AuthSession> buildSession(Ref ref) {
        buildCount++;
        return Stream.value(
          const AuthSession(uid: 'u1', customClaims: {}),
        );
      }

      final tokenController = StreamController<void>.broadcast();
      addTearDown(tokenController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(buildSession),
            idTokenChangesProvider.overrideWith(
              (ref) => tokenController.stream,
            ),
          ],
          child: MaterialApp(
            home: ClaimRefreshObserver(
              // Long enough that the periodic timer can't fire during this
              // test and confound the idToken-tick assertions.
              periodicInterval: const Duration(minutes: 30),
              child: watchingChild(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final afterMount = buildCount;

      // First real tick (post-mount) must trigger a refresh.
      tokenController.add(null);
      await tester.pumpAndSettle();
      expect(buildCount, greaterThan(afterMount));
      final afterFirstTick = buildCount;

      // A second tick arriving immediately after (as a forced token refresh
      // can itself trigger idTokenChanges) must be swallowed by the
      // cooldown, not cause another rebuild — otherwise this would loop
      // forever refreshing itself.
      tokenController.add(null);
      await tester.pump();
      expect(buildCount, afterFirstTick);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'platform-admin gated route access updates after a claim refresh',
    (tester) async {
      var buildCount = 0;
      Stream<AuthSession> buildSession(Ref ref) {
        buildCount++;
        // Simulate platformAdmin being revoked: granted on the first
        // build, gone by the time the observer forces a rebuild.
        final claims =
            buildCount == 1 ? {'platformAdmin': true} : <String, dynamic>{};
        return Stream.value(
          AuthSession(uid: 'admin-1', customClaims: claims),
        );
      }

      final router = GoRouter(
        initialLocation: '/admin-gated',
        routes: [
          GoRoute(
            path: '/admin-gated',
            builder: (_, __) => ClaimRefreshObserver(
              child: const AdminPlatformGate(child: Text('admin content')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authSessionProvider.overrideWith(buildSession)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      // AdminPlatformGate's own mount-time invalidate may already have
      // consumed the "revoked" build; either way admin content is gone or
      // about to be after the next forced refresh below.

      WidgetsBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('admin content'), findsNothing);
      expect(
        find.text('נדרשת הרשאת מנהל מערכת ב־Firebase'),
        findsOneWidget,
      );
    },
  );
}
