import 'dart:async';

import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/router/app_router.dart';
import 'package:construction_rfq/screens/auth/login_screen.dart';
import 'package:construction_rfq/screens/auth/no_permission_screen.dart';
import 'package:construction_rfq/services/auth_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/auth_logout_redirect_stub.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TrackingAuthService extends AuthService {
  _TrackingAuthService(this._onLogout);

  int logoutCalls = 0;
  final Future<void> Function() _onLogout;

  @override
  Future<void> logout() async {
    logoutCalls++;
    await _onLogout();
  }
}

void main() {
  group('no permission logout', () {
    late _TrackingAuthService authService;

    AuthSession sessionFor(String uid) => AuthSession(
          uid: uid,
          profile: AppUser(
            id: uid,
            fullName: 'משתמש ללא שיוך',
            email: 'lonely@test.com',
            phone: '050',
            userType: UserType.commercialCustomer,
            city: 'תל אביב',
            createdAt: DateTime(2026),
          ),
        );

    setUp(() {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      MockStore.instance.loginAsDemo(UserType.commercialCustomer);
      authService = _TrackingAuthService(() async {
        MockStore.instance.logout();
      });
    });

    tearDown(() {
      AppMode.isDemoMode = false;
      MockStore.instance.logout();
      debugSimulateHardWebLoginRedirect = false;
      hardLoginRedirectCount = 0;
    });

    testWidgets('simulated web hard logout invokes hard redirect hook', (tester) async {
      debugSimulateHardWebLoginRedirect = true;
      hardLoginRedirectCount = 0;

      final router = GoRouter(
        initialLocation: '/no-permission',
        routes: [
          GoRoute(
            path: '/no-permission',
            builder: (_, __) => const NoPermissionScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const LoginScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(sessionFor('lonely-user')),
            ),
            authBootstrapSettledProvider.overrideWithValue(true),
            membershipBootstrapSettledProvider.overrideWithValue(true),
            currentUserMembershipsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(HebrewStrings.logout));
      await tester.pumpAndSettle();

      expect(authService.logoutCalls, 1);
      expect(hardLoginRedirectCount, 1);
      expect(MockStore.instance.currentUser, isNull);
    });

    testWidgets('non-web logout uses router to login', (tester) async {
      final authStream = StreamController<AuthSession>.broadcast();
      addTearDown(authStream.close);
      authService = _TrackingAuthService(() async {
        MockStore.instance.logout();
        authStream.add(AuthSession.empty);
      });

      final router = GoRouter(
        initialLocation: '/no-permission',
        routes: [
          GoRoute(
            path: '/no-permission',
            builder: (_, __) => const NoPermissionScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const LoginScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            authSessionProvider.overrideWith(
              (ref) async* {
                yield sessionFor('lonely-user');
                yield* authStream.stream;
              },
            ),
            authBootstrapSettledProvider.overrideWithValue(true),
            membershipBootstrapSettledProvider.overrideWithValue(true),
            currentUserMembershipsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('אין לך הרשאות למערכת'), findsOneWidget);

      await tester.tap(find.text(HebrewStrings.logout));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(authService.logoutCalls, 1);
      expect(MockStore.instance.currentUser, isNull);
      expect(router.state.matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('logout still routes to login when already signed out',
        (tester) async {
      MockStore.instance.logout();
      final router = GoRouter(
        initialLocation: '/no-permission',
        routes: [
          GoRoute(
            path: '/no-permission',
            builder: (_, __) => const NoPermissionScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('LOGIN_PAGE')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(AuthSession.empty),
            ),
            resolvedAuthSessionProvider.overrideWith(
              (ref) => const AsyncValue.data(AuthSession.empty),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(HebrewStrings.logout));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/login');
      expect(find.text('LOGIN_PAGE'), findsOneWidget);
    });

    testWidgets('routerProvider keeps login during forced logout with stale session',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(sessionFor('lonely-user')),
          ),
          resolvedAuthSessionProvider.overrideWith(
            (ref) => AsyncValue.data(sessionFor('lonely-user')),
          ),
          authBootstrapSettledProvider.overrideWithValue(true),
          membershipBootstrapSettledProvider.overrideWithValue(true),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoPermissionScreen), findsOneWidget);

      container.read(forceLoginProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(container.read(forceLoginProvider), isTrue);
    });

    testWidgets('logout from no-permission does not return to no-permission',
        (tester) async {
      final authStream = StreamController<AuthSession>.broadcast();
      addTearDown(authStream.close);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            _TrackingAuthService(() async {
              await Future<void>.delayed(const Duration(milliseconds: 300));
              MockStore.instance.logout();
              authStream.add(AuthSession.empty);
            }),
          ),
          authSessionProvider.overrideWith(
            (ref) async* {
              yield sessionFor('lonely-user');
              yield* authStream.stream;
            },
          ),
          authBootstrapSettledProvider.overrideWithValue(true),
          membershipBootstrapSettledProvider.overrideWithValue(true),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
      );
      addTearDown(container.dispose);

      late GoRouter router;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              router = ref.watch(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/no-permission');
      await tester.pumpAndSettle();
      expect(find.byType(NoPermissionScreen), findsOneWidget);

      await tester.tap(find.text(HebrewStrings.logout));
      await tester.pumpAndSettle();

      expect(find.byType(NoPermissionScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(router.state.matchedLocation, '/login');
      expect(container.read(forceLoginProvider), isFalse);
    });
  });
}
