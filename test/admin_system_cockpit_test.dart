import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/organization.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/providers/admin_management_providers.dart';
import 'package:construction_rfq/providers/admin_providers.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/admin_management_repository.dart';
import 'package:construction_rfq/repositories/admin_repository.dart';
import 'package:construction_rfq/screens/admin/admin_console_screen.dart';
import 'package:construction_rfq/screens/admin/admin_org_list_screen.dart';
import 'package:construction_rfq/screens/admin/admin_projects_screen.dart';
import 'package:construction_rfq/screens/admin/admin_system_cockpit.dart';
import 'package:construction_rfq/screens/admin/admin_users_screen.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    AdminManagementRepository.resetDemoStores();
  });

  Organization demoOrg({
    required String id,
    required String name,
    required OrganizationType type,
  }) {
    return Organization(
      id: id,
      type: type,
      name: name,
      ownerUid: 'owner-$id',
      status: 'active',
      createdAt: DateTime(2026),
    );
  }

  List<Override> adminOverrides({
    List<Organization> orgs = const [],
  }) {
    return [
      hasPlatformAdminClaimProvider.overrideWith((ref) => true),
      adminOverviewCountsProvider.overrideWith(
        (ref) async => const AdminOverviewCounts(
          users: 1,
          projects: 1,
          requests: 1,
          suppliers: 1,
          quotes: 1,
        ),
      ),
      adminOrganizationsProvider.overrideWith((ref) async => orgs),
      adminContractorOrganizationsProvider.overrideWith((ref) async {
        return orgs.where((o) => o.type == OrganizationType.contractor).toList();
      }),
      adminSupplierOrganizationsProvider.overrideWith((ref) async {
        return orgs.where((o) => o.type == OrganizationType.supplier).toList();
      }),
      adminRecentUsersProvider.overrideWith((ref) async => []),
      adminRecentProjectsProvider.overrideWith((ref) async => []),
      adminRecentRequestsProvider.overrideWith((ref) async => []),
      adminSuppliersProvider.overrideWith((ref) async => []),
      adminRecentQuotesProvider.overrideWith((ref) async => []),
      adminAllUsersProvider.overrideWith((ref) async => []),
      adminAllProjectsProvider.overrideWith((ref) async => []),
      adminAllMembershipsProvider.overrideWith((ref) async => []),
      adminOrgSummaryProvider.overrideWith(
        (ref, orgId) async => const AdminOrgSummary(
          userCount: 2,
          projectCount: 1,
        ),
      ),
      adminOrganizationProvider.overrideWith((ref, orgId) async {
        return orgs.where((o) => o.id == orgId).firstOrNull;
      }),
    ];
  }

  Widget adminRouter({
    required List<Override> overrides,
    String initialLocation = '/admin',
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminConsoleScreen(),
              routes: [
                GoRoute(
                  path: 'contractors',
                  builder: (_, __) => const AdminContractorCompaniesScreen(),
                ),
                GoRoute(
                  path: 'suppliers',
                  builder: (_, __) => const AdminSupplierCompaniesScreen(),
                ),
                GoRoute(
                  path: 'users',
                  builder: (_, __) => const AdminUsersManagementScreen(),
                ),
                GoRoute(
                  path: 'projects',
                  builder: (_, __) => const AdminProjectsManagementScreen(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Finder cockpitButton(String label) {
    return find.descendant(
      of: find.byType(AdminSystemCockpit),
      matching: find.widgetWithText(FilledButton, label),
    );
  }

  testWidgets('admin system actions are rendered as enabled buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      adminRouter(overrides: adminOverrides()),
    );
    await tester.pumpAndSettle();

    expect(cockpitButton('ניהול חברות קבלן'), findsOneWidget);
    expect(cockpitButton('ניהול ספקים'), findsOneWidget);
    expect(cockpitButton('ניהול משתמשים'), findsOneWidget);
    expect(cockpitButton('ניהול פרויקטים'), findsOneWidget);

    final contractorButton = tester.widget<FilledButton>(
      cockpitButton('ניהול חברות קבלן'),
    );
    expect(contractorButton.onPressed, isNotNull);
  });

  testWidgets('tapping contractor companies action opens contractor list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final orgs = [
      demoOrg(id: 'launch-org-dimri', name: 'דימרי', type: OrganizationType.contractor),
    ];

    await tester.pumpWidget(
      adminRouter(
        overrides: adminOverrides(orgs: orgs),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cockpitButton('ניהול חברות קבלן'));
    await tester.pumpAndSettle();

    expect(find.text('ניהול חברות קבלן'), findsWidgets);
    expect(find.text('דימרי'), findsOneWidget);
    expect(find.text('פתח'), findsOneWidget);
    expect(find.text('צוות והרשאות'), findsOneWidget);
  });

  testWidgets('tapping supplier companies action opens supplier list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final orgs = [
      demoOrg(id: 'launch-org-frishman', name: 'פרישמן', type: OrganizationType.supplier),
    ];

    await tester.pumpWidget(
      adminRouter(
        overrides: adminOverrides(orgs: orgs),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(cockpitButton('ניהול ספקים'));
    await tester.pumpAndSettle();

    expect(find.text('פרישמן'), findsOneWidget);
  });

  testWidgets('tapping users action opens users management list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(adminRouter(overrides: adminOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(cockpitButton('ניהול משתמשים'));
    await tester.pumpAndSettle();

    expect(find.text('חזרה לניהול מערכת'), findsOneWidget);
  });

  testWidgets('tapping projects action opens projects management list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(adminRouter(overrides: adminOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(cockpitButton('ניהול פרויקטים'));
    await tester.pumpAndSettle();

    expect(find.text('ניהול פרויקטים'), findsWidgets);
  });

  testWidgets('fake actions render disabled coming soon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: const Scaffold(body: AdminSystemCockpit())),
    );
    await tester.pumpAndSettle();

    final requestsButton = tester.widget<OutlinedButton>(
      find.widgetWithText(
        OutlinedButton,
        'ניהול בקשות והזמנות יתווסף בהמשך',
      ),
    );
    expect(requestsButton.onPressed, isNull);

    final settingsButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'הגדרות מערכת — בקרוב'),
    );
    expect(settingsButton.onPressed, isNull);
  });

  testWidgets('company owner does not get global system tree', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasPlatformAdminClaimProvider.overrideWith((ref) => false),
          effectivePermissionsProvider.overrideWith(
            (ref) => Permission.values.toSet(),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: MockStore.demoCustomer.id,
                profile: MockStore.demoCustomer,
              ),
            ),
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

    expect(find.text('ניהול חברות קבלן'), findsNothing);
    expect(find.text('עץ חברה'), findsWidgets);
  });

  testWidgets('regular user cannot access admin cockpit', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasPlatformAdminClaimProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const AdminConsoleScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('נדרשת הרשאת מנהל מערכת'), findsOneWidget);
    expect(find.text('ניהול חברות קבלן'), findsNothing);
  });
}
