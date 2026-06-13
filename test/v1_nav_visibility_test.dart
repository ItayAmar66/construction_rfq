import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/screens/admin/admin_console_screen.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.loginAsDemo(
      MockStore.demoCustomer.userType,
    );
  });

  testWidgets('admin console denies non-admin', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: MockStore.instance.currentUser?.id,
                profile: MockStore.instance.currentUser,
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
    expect(find.textContaining('נדרשת הרשאת מנהל מערכת'), findsOneWidget);
  });

  testWidgets('contractor company screen shows sections for legacy customer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: MockStore.instance.currentUser?.id,
                profile: MockStore.instance.currentUser,
              ),
            ),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => Permission.values.toSet(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const ContractorCompanyScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(HebrewStrings.contractorCompanyTitle), findsOneWidget);
    expect(find.text('עץ חברה'), findsWidgets);
    expect(find.text('משתמשים והרשאות'), findsOneWidget);
    expect(find.textContaining('רכש'), findsWidgets);
  });
}
