import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/enterprise/project_status.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/project_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/screens/projects/project_workspace_screen.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/project_procurement_summary.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:construction_rfq/widgets/projects/dashboard_projects_section.dart';
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
    MockStore.instance.loginAsDemo(UserType.commercialCustomer);
  });

  group('Project lifecycle', () {
    test('manager can mark project completed', () async {
      final repo = ProjectRepository();
      final owner = MockStore.instance.currentUser!.id;
      final project = await repo.createProject(
        ownerUid: owner,
        name: 'אתר א',
        location: 'רחוב 1',
      );

      final completed = await repo.completeProject(
        projectId: project.id,
        ownerUid: owner,
      );
      expect(completed.status, ProjectStatus.completed);
      expect(completed.completedAt, isNotNull);
    });

    test('manager can request deletion with ~24h schedule', () async {
      final repo = ProjectRepository();
      final owner = MockStore.instance.currentUser!.id;
      final project = await repo.createProject(
        ownerUid: owner,
        name: 'אתר ב',
      );

      final pending = await repo.requestProjectDeletion(
        projectId: project.id,
        ownerUid: owner,
      );
      expect(pending.status, ProjectStatus.deletionPending);
      expect(pending.deletionScheduledFor, isNotNull);
      final delta = pending.deletionScheduledFor!.difference(DateTime.now());
      expect(delta.inHours, greaterThanOrEqualTo(23));
      expect(delta.inHours, lessThanOrEqualTo(24));
    });

    test('cancel deletion restores project', () async {
      final repo = ProjectRepository();
      final owner = MockStore.instance.currentUser!.id;
      final project = await repo.createProject(ownerUid: owner, name: 'אתר ג');
      await repo.requestProjectDeletion(projectId: project.id, ownerUid: owner);
      final restored = await repo.cancelProjectDeletion(
        projectId: project.id,
        ownerUid: owner,
      );
      expect(restored.status, ProjectStatus.active);
      expect(restored.isDeletionPending, isFalse);
    });

    test('engineer cannot delete project via permissions', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        const [EnterpriseRole.engineer],
      );
      expect(perms.contains(Permission.manageProjects), isFalse);
      expect(perms.contains(Permission.submitRfq), isFalse);
    });

    test('project is not hard deleted immediately', () async {
      final repo = ProjectRepository();
      final owner = MockStore.instance.currentUser!.id;
      final project = await repo.createProject(ownerUid: owner, name: 'אתר ד');
      await repo.requestProjectDeletion(projectId: project.id, ownerUid: owner);
      expect(MockStore.instance.getProject(project.id), isNotNull);
    });
  });

  group('Project procurement summary', () {
    test('empty project cost summary renders', () {
      final summary = ProjectProcurementSummary.build(
        projectId: 'p1',
        requests: const [],
        quotes: const [],
      );
      expect(summary.totalApprovedCost, 0);
      expect(summary.winners, isEmpty);
    });

    test('approved quote fixture creates winning supplier row', () {
      final summary = ProjectProcurementSummary.build(
        projectId: 'p1',
        requests: [
          QuoteRequest(
            id: 'r1',
            customerId: 'c1',
            customerName: 'קבלן',
            customerPhone: '050',
            customerCity: 'TLV',
            customerType: 'commercialCustomer',
            status: QuoteRequestStatus.ordered,
            createdAt: DateTime(2026, 1, 1),
            projectId: 'p1',
            approvedQuoteId: 'q1',
          ),
        ],
        quotes: [
          // ignore: avoid_redundant_argument_values
          SupplierQuote(
            id: 'q1',
            quoteRequestId: 'r1',
            supplierId: 's1',
            supplierName: 'ספק זוכה',
            supplierType: 'commercialSupplier',
            deliveryTime: '3 ימים',
            totalPrice: 1500,
            status: SupplierQuoteStatus.approved,
            createdAt: DateTime(2026, 1, 2),
          ),
        ],
      );
      expect(summary.winners, hasLength(1));
      expect(summary.winners.first.supplierName, 'ספק זוכה');
      expect(summary.totalApprovedCost, 1500);
    });

    test('rejected quotes are excluded', () {
      final summary = ProjectProcurementSummary.build(
        projectId: 'p1',
        requests: [
          QuoteRequest(
            id: 'r2',
            customerId: 'c1',
            customerName: 'קבלן',
            customerPhone: '050',
            customerCity: 'TLV',
            customerType: 'commercialCustomer',
            status: QuoteRequestStatus.ordered,
            createdAt: DateTime(2026),
            projectId: 'p1',
            approvedQuoteId: 'q2',
          ),
        ],
        quotes: [
          SupplierQuote(
            id: 'q2',
            quoteRequestId: 'r2',
            supplierId: 's1',
            supplierName: 'ספק',
            supplierType: 'commercialSupplier',
            deliveryTime: '3 ימים',
            totalPrice: 500,
            status: SupplierQuoteStatus.rejected,
            createdAt: DateTime(2026),
          ),
        ],
      );
      expect(summary.winners, isEmpty);
    });

    test('unrelated project quotes excluded', () {
      final summary = ProjectProcurementSummary.build(
        projectId: 'p1',
        requests: [
          QuoteRequest(
            id: 'r3',
            customerId: 'c1',
            customerName: 'קבלן',
            customerPhone: '050',
            customerCity: 'TLV',
            customerType: 'commercialCustomer',
            status: QuoteRequestStatus.ordered,
            createdAt: DateTime(2026),
            projectId: 'other',
            approvedQuoteId: 'q3',
          ),
        ],
        quotes: [
          SupplierQuote(
            id: 'q3',
            quoteRequestId: 'r3',
            supplierId: 's1',
            supplierName: 'ספק',
            supplierType: 'commercialSupplier',
            deliveryTime: '3 ימים',
            totalPrice: 900,
            status: SupplierQuoteStatus.approved,
            createdAt: DateTime(2026),
          ),
        ],
      );
      expect(summary.winners, isEmpty);
    });
  });

  testWidgets('project card opens workspace', (tester) async {
    final owner = MockStore.instance.currentUser!.id;
    final project = await ProjectRepository().createProject(
      ownerUid: owner,
      name: 'Workspace Test',
      location: 'Site 1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                uid: owner,
                profile: MockStore.instance.currentUser,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const DashboardProjectsSection(),
              ),
              GoRoute(
                path: '/projects/:projectId',
                builder: (_, state) => ProjectWorkspaceScreen(
                  projectId: state.pathParameters['projectId']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Workspace Test'), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.text('Workspace Test')),
    );
    router.go('/projects/${project.id}');
    await tester.pumpAndSettle();
    expect(find.text('Workspace Test'), findsWidgets);
    expect(find.text('הזמנה חדשה'), findsOneWidget);
    expect(find.text('פרויקט'), findsOneWidget);
  });

  testWidgets('manager sees role management engineer does not', (tester) async {
    final manager = MockStore.demoCustomer;
    final membership = Membership(
      uid: manager.id,
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorCompanyOwner],
    );
    MockStore.instance.setDemoMembership(membership);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(uid: manager.id, profile: manager),
            ),
          ),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value([membership]),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.contractorCompanyOwner],
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
    expect(find.text('עץ חברה'), findsWidgets);
    expect(find.text('מנהל חברה'), findsWidgets);
  });

  testWidgets('engineer does not see role management controls', (tester) async {
    final engineer = AppUser(
      id: 'eng-ui',
      fullName: 'מהנדס',
      email: 'eng@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'TLV',
      createdAt: DateTime(2026),
    );
    final membership = Membership(
      uid: engineer.id,
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.engineer],
    );
    MockStore.instance.setDemoMembership(membership);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(uid: engineer.id, profile: engineer),
            ),
          ),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value([membership]),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.engineer],
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
    expect(find.text('אין הרשאת ניהול חברה'), findsOneWidget);
  });

  test('procurement cannot promote to manager', () {
    MockStore.instance.setDemoMembership(
      Membership(
        uid: 'proc-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
      ),
    );
    MockStore.instance.setDemoMembership(
      Membership(
        uid: 'eng-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      ),
    );

    expect(
      () => OrganizationRepository().updateMemberRole(
        orgId: 'org-1',
        memberUid: 'eng-1',
        newRole: EnterpriseRole.contractorCompanyOwner,
        actorUid: 'proc-1',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
