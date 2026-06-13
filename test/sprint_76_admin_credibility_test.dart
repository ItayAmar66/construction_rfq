import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/admin/admin_console_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/platform_admin.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/widgets/app_shell.dart';
import 'package:construction_rfq/widgets/auth_form_layout.dart';
import 'package:construction_rfq/widgets/platform_admin_role_badge.dart';
import 'package:construction_rfq/widgets/projects/create_project_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
  });

  testWidgets('platformAdmin claim sees admin nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: 'admin-1',
                profile: AppUser(
                  id: 'admin-1',
                  fullName: 'Admin',
                  email: 'admin@admin.com',
                  phone: '050',
                  userType: UserType.commercialCustomer,
                  city: 'IL',
                  createdAt: DateTime(2026),
                ),
                customClaims: {PlatformAdmin.claimKey: true},
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: AppShell(
            currentPath: '/home',
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(HebrewStrings.adminConsoleTitle), findsOneWidget);
  });

  testWidgets('normal customer does not see admin nav', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: MockStore.demoCustomer.id,
                profile: MockStore.demoCustomer,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: AppShell(
            currentPath: '/home',
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(HebrewStrings.adminConsoleTitle), findsNothing);
  });

  testWidgets('bootstrap admin email shows role badge without claim', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: 'admin-ui',
                profile: AppUser(
                  id: 'admin-ui',
                  fullName: 'Admin UI',
                  email: 'admin@admin.com',
                  phone: '050',
                  userType: UserType.commercialCustomer,
                  city: 'IL',
                  createdAt: DateTime(2026),
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PlatformAdminRoleBadge()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(PlatformAdminRoleBadge.label), findsOneWidget);
  });

  testWidgets('admin console opens for bootstrap admin', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: 'admin-ui',
                profile: AppUser(
                  id: 'admin-ui',
                  fullName: 'Admin UI',
                  email: 'admin@admin.com',
                  phone: '050',
                  userType: UserType.commercialCustomer,
                  city: 'IL',
                  createdAt: DateTime(2026),
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const AdminConsoleScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('משתמשים'), findsWidgets);
    expect(find.text('פרויקטים'), findsWidgets);
    expect(find.textContaining('מנהל מערכת'), findsWidgets);
  });

  testWidgets('auth form is width constrained on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    double? childWidth;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthFormLayout(
            child: LayoutBuilder(
              builder: (context, constraints) {
                childWidth = constraints.maxWidth;
                return const SizedBox(height: 200);
              },
            ),
          ),
        ),
      ),
    );

    expect(childWidth, closeTo(AuthFormLayout.defaultMaxWidth, 1));
  });

  testWidgets('project dialog shows inline validation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CreateProjectDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(HebrewStrings.saveProject));
    await tester.pump();
    expect(find.text('יש להזין שם פרויקט'), findsOneWidget);
    expect(find.text('יש להזין מיקום / כתובת'), findsOneWidget);
  });
}
