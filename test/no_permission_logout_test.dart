import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/auth/login_screen.dart';
import 'package:construction_rfq/screens/auth/no_permission_screen.dart';
import 'package:construction_rfq/services/auth_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
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
    });

    testWidgets('logout button signs out and routes to login', (tester) async {
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
            resolvedAuthSessionProvider.overrideWith(
              (ref) => AsyncValue.data(sessionFor('lonely-user')),
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
      await tester.pumpAndSettle();

      expect(authService.logoutCalls, 1);
      expect(MockStore.instance.currentUser, isNull);
      expect(router.state.matchedLocation, '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
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
  });
}
