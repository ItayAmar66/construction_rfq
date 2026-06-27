import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/admin_providers.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/admin_repository.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/screens/admin/admin_console_screen.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/screens/projects/project_workspace_screen.dart';
import 'package:construction_rfq/screens/supplier/supplier_company_screen.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/models/enterprise/hierarchy_node.dart';
import 'package:construction_rfq/utils/enterprise_hierarchy_presets.dart';
import 'package:construction_rfq/widgets/permissions/permission_capability_chips.dart';
import 'package:construction_rfq/widgets/permissions/permission_hierarchy_tree.dart';
import 'package:construction_rfq/widgets/permissions/permission_matrix_card.dart';
import 'package:construction_rfq/widgets/permissions/permission_scope_badge.dart';
import 'package:construction_rfq/widgets/permissions/role_read_only_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.projects.clear();
    MockStore.instance.demoMemberships.clear();
  });

  group('Hierarchy widgets', () {
    testWidgets('tree renders nested nodes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionHierarchyTree(
                root: EnterpriseHierarchyPresets.contractorCompany.root,
              ),
            ),
          ),
        ),
      );
      expect(find.text('מנהל חברה'), findsWidgets);
      expect(find.text('מהנדס'), findsWidgets);
    });

    testWidgets('capability chips render', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionCapabilityChips(
              capabilities: ['יצירת בקשות', 'שליחה לספקים'],
            ),
          ),
        ),
      );
      expect(find.text('יצירת בקשות'), findsOneWidget);
    });

    testWidgets('disabled edit notice appears', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RoleReadOnlyNotice()),
        ),
      );
      expect(find.text('עריכת הרשאות בקרוב'), findsOneWidget);
    });

    testWidgets('scope badges render', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PermissionScopeBadge(scope: RoleScopeType.company),
          ),
        ),
      );
      expect(find.text('חברה'), findsOneWidget);
    });

    testWidgets('RTL tree does not crash', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('he'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: PermissionHierarchyTree(
                  root: EnterpriseHierarchyPresets.supplierCompany.root,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('מנהל ספק'), findsWidgets);
    });

    testWidgets('permission matrix cards render', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: PermissionMatrixSection(
                title: 'סיכום',
                summaries: EnterpriseHierarchyPresets.contractorMatrix,
              ),
            ),
          ),
        ),
      );
      expect(find.text('מנהל חברה'), findsOneWidget);
      expect(find.text('רכש'), findsOneWidget);
    });
  });

  group('Contractor company screen', () {
    Widget wrap(Widget child, {List<Override> overrides = const []}) {
      return ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: MockStore.demoCustomer.id,
                profile: MockStore.demoCustomer,
              ),
            ),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.contractorCompanyOwner],
            ),
          ),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          ...overrides,
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, __) => child),
            ],
          ),
        ),
      );
    }

    testWidgets('renders company tree tab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(const ContractorCompanyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('עץ חברה'), findsWidgets);
      expect(find.text('מנהל חברה'), findsWidgets);
      expect(find.text('רכש'), findsWidgets);
      expect(find.text('מהנדס'), findsWidgets);
    });

    testWidgets('renders read-only notice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(const ContractorCompanyScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('צוות והרשאות'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('שינוי הרשאות יופעל'),
        findsOneWidget,
      );
    });

    testWidgets('no fake users when memberships empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(const ContractorCompanyScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('צוות והרשאות'));
      await tester.pumpAndSettle();
      expect(find.text('עדיין אין צוות מחובר לחברה'), findsOneWidget);
    });
  });

  group('Supplier company screen', () {
    testWidgets('renders supplier tree', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      MockStore.instance.loginAsDemo(UserType.commercialSupplier);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                AuthSession(
                  uid: MockStore.instance.currentUser!.id,
                  profile: MockStore.instance.currentUser,
                ),
              ),
            ),
            effectivePermissionsProvider.overrideWith(
              (ref) => EnterprisePermissionService.permissionsForRoles(
                const [EnterpriseRole.supplierOwner],
              ),
            ),
            currentUserMembershipsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const SupplierCompanyScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('עץ ספק'), findsWidgets);
      expect(find.text('מנהל ספק'), findsWidgets);
      expect(find.text('מנהל מכירות'), findsWidgets);
      expect(find.text('נציג מכירות'), findsWidgets);
      expect(find.text('תפעול'), findsWidgets);
    });
  });

  group('Project workspace hierarchy', () {
    testWidgets('renders team section and order CTA', (tester) async {
      MockStore.instance.loginAsDemo(UserType.commercialCustomer);
      final owner = MockStore.instance.currentUser!.id;
      final project = await ProjectRepository().createProject(
        ownerUid: owner,
        name: 'Hierarchy Site',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                AuthSession(uid: owner, profile: MockStore.instance.currentUser),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/projects/${project.id}',
              routes: [
                GoRoute(
                  path: '/projects/:projectId',
                  builder: (_, s) => ProjectWorkspaceScreen(
                    projectId: s.pathParameters['projectId']!,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('צוות והרשאות בפרויקט'), findsOneWidget);
      expect(find.text('רכש משויך'), findsOneWidget);
      expect(find.text('הזמנה חדשה'), findsOneWidget);
    });
  });

  group('Admin console hierarchy', () {
    testWidgets('shows platform admin distinction', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            showAdminNavProvider.overrideWith((ref) => true),
            hasPlatformAdminClaimProvider.overrideWith((ref) => true),
            adminOverviewCountsProvider.overrideWith(
              (ref) async => AdminOverviewCounts(
                users: 1,
                projects: 1,
                requests: 1,
                suppliers: 1,
                quotes: 1,
              ),
            ),
            adminRecentUsersProvider.overrideWith((ref) async => []),
            adminRecentProjectsProvider.overrideWith((ref) async => []),
            adminRecentRequestsProvider.overrideWith((ref) async => []),
            adminSuppliersProvider.overrideWith((ref) async => []),
            adminRecentQuotesProvider.overrideWith((ref) async => []),
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
      expect(find.text('מנהל מערכת'), findsWidgets);
      expect(find.textContaining('מנהל מערכת ≠ מנהל חברה'), findsWidgets);
    });
  });
}
