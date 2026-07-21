import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/router/app_router.dart';
import 'package:construction_rfq/screens/customer/customer_dashboard_screen.dart';
import 'package:construction_rfq/screens/supplier/incoming_requests_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/platform_access_gate.dart';
import 'package:construction_rfq/widgets/supplier_only_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Covers PR requirement: block non-supplier users from /incoming,
/// /sent-quotes, /supplier/orders via both a declarative router redirect and
/// a screen-level fallback guard (SupplierOnlyGate), not just hidden nav.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  AuthSession sessionFor(String uid, UserType userType) => AuthSession(
        uid: uid,
        profile: AppUser(
          id: uid,
          fullName: 'משתמש בדיקה',
          email: 'test@test.com',
          phone: '050',
          userType: userType,
          city: 'תל אביב',
          createdAt: DateTime(2026),
        ),
      );

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
    MockStore.instance.logout();
  });

  ProviderContainer buildContainer(AuthSession session) => ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith((ref) => Stream.value(session)),
          resolvedAuthSessionProvider.overrideWith(
            (ref) => AsyncValue.data(session),
          ),
          authBootstrapSettledProvider.overrideWithValue(true),
          membershipBootstrapSettledProvider.overrideWithValue(true),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          platformAccessGateProvider.overrideWithValue(
            PlatformAccessGate.granted,
          ),
        ],
      );

  group('router-level supplier-only redirect', () {
    testWidgets(
      'contractor navigating to /incoming is redirected away, no loop',
      (tester) async {
        final container = buildContainer(
          sessionFor('contractor-1', UserType.commercialCustomer),
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

        router.go('/incoming');
        await tester.pumpAndSettle();

        expect(router.state.matchedLocation, '/home');
        expect(find.byType(IncomingRequestsScreen), findsNothing);
        expect(find.byType(CustomerDashboardScreen), findsOneWidget);

        // Settling again must not bounce the location further (no
        // redirect loop between the guarded route and its fallback).
        await tester.pumpAndSettle();
        expect(router.state.matchedLocation, '/home');
      },
    );

    for (final route in ['/incoming', '/supplier/orders', '/sent-quotes']) {
      testWidgets('supplier navigating to $route is allowed through',
          (tester) async {
        final container = buildContainer(
          sessionFor('supplier-1', UserType.commercialSupplier),
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

        router.go(route);
        await tester.pumpAndSettle();

        expect(router.state.matchedLocation, route);
      });
    }

    testWidgets('logged-out user hitting /incoming still redirects to login',
        (tester) async {
      final container = buildContainer(AuthSession.empty);
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

      router.go('/incoming');
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, '/login');
    });
  });

  group('SupplierOnlyGate screen-level fallback', () {
    GoRouter buildGateRouter() => GoRouter(
          initialLocation: '/gated',
          routes: [
            GoRoute(
              path: '/gated',
              builder: (_, __) => const SupplierOnlyGate(
                child: Text('supplier-only content'),
              ),
            ),
          ],
        );

    testWidgets('blocks a contractor session even without a router redirect',
        (tester) async {
      final session = sessionFor('contractor-1', UserType.commercialCustomer);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolvedAuthSessionProvider.overrideWith(
              (ref) => AsyncValue.data(session),
            ),
          ],
          child: MaterialApp.router(routerConfig: buildGateRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('supplier-only content'), findsNothing);
      expect(find.text('אין הרשאה'), findsOneWidget);
    });

    testWidgets('allows a supplier session through', (tester) async {
      final session = sessionFor('supplier-1', UserType.commercialSupplier);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolvedAuthSessionProvider.overrideWith(
              (ref) => AsyncValue.data(session),
            ),
          ],
          child: MaterialApp.router(routerConfig: buildGateRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('supplier-only content'), findsOneWidget);
    });
  });
}
