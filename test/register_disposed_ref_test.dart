import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/auth/register_screen.dart';
import 'package:construction_rfq/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeAuthService extends AuthService {
  @override
  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required UserType userType,
    required String city,
    String? notes,
    required String requestedCompanyName,
    String? requestedRole,
    String? requestedProjectName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('registration completes without disposed ref error', (tester) async {
    AppMode.isDemoMode = true;
    AppMode.isFirebaseInitialized = false;

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('home'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'קבלן QA');
    await tester.enterText(find.byType(TextFormField).at(1), '050-1111111');
    await tester.enterText(find.byType(TextFormField).at(2), 'qa@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret1');
    await tester.enterText(find.byType(TextFormField).at(4), 'תל אביב');

    await tester.tap(find.text('צור חשבון'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
