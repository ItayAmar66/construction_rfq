import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/repositories/project_assignment_repository.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/screens/projects/project_workspace_screen.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/enterprise_role_labels.dart';
import 'package:construction_rfq/widgets/permissions/membership_row_card.dart';
import 'package:construction_rfq/widgets/permissions/role_change_dialog.dart';
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

  // ─── Role label tests ───────────────────────────────────────────────────
  group('EnterpriseRoleLabels', () {
    test('contractor company owner label', () {
      expect(EnterpriseRoleLabels.hebrew(EnterpriseRole.contractorCompanyOwner),
          'מנהל חברה');
    });
    test('supplier owner label', () {
      expect(
          EnterpriseRoleLabels.hebrew(EnterpriseRole.supplierOwner), 'מנהל ספק');
    });
    test('platform admin label', () {
      expect(EnterpriseRoleLabels.hebrew(EnterpriseRole.platformAdmin),
          'מנהל מערכת');
    });
    test('engineer label', () {
      expect(
          EnterpriseRoleLabels.hebrew(EnterpriseRole.engineer), 'מהנדס');
    });
    test('viewer labels', () {
      expect(EnterpriseRoleLabels.hebrew(EnterpriseRole.contractorViewer),
          'צפייה בלבד');
      expect(EnterpriseRoleLabels.hebrew(EnterpriseRole.supplierViewer),
          'צפייה בלבד');
    });
    test('supplier assignable roles list exists', () {
      expect(EnterpriseRoleLabels.supplierAssignableRoles,
          contains(EnterpriseRole.supplierOwner));
      expect(EnterpriseRoleLabels.supplierAssignableRoles,
          contains(EnterpriseRole.supplierSalesRep));
    });
    test('role descriptions non-empty', () {
      for (final role in EnterpriseRole.values) {
        expect(EnterpriseRoleLabels.description(role), isNotEmpty,
            reason: 'missing description for $role');
      }
    });
  });

  // ─── MockStore membership reads ─────────────────────────────────────────
  group('MockStore membership reads', () {
    test('watchMembershipsForUser returns stored memberships', () async {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'user-1',
        orgId: 'org-a',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
      ));
      final list =
          await MockStore.instance.watchMembershipsForUser('user-1').first;
      expect(list, hasLength(1));
      expect(list.first.roles, contains(EnterpriseRole.procurementManager));
    });

    test('watchMembershipsForOrg returns all members of org', () async {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'u1',
        orgId: 'org-b',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      ));
      MockStore.instance.setDemoMembership(Membership(
        uid: 'u2',
        orgId: 'org-b',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
      ));
      MockStore.instance.setDemoMembership(Membership(
        uid: 'u3',
        orgId: 'org-c',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorCompanyOwner],
      ));
      final list =
          await MockStore.instance.watchMembershipsForOrg('org-b').first;
      expect(list, hasLength(2));
    });

    test('empty org returns empty list', () async {
      final list =
          await MockStore.instance.watchMembershipsForOrg('no-such-org').first;
      expect(list, isEmpty);
    });
  });

  // ─── OrganizationRepository guardrails ──────────────────────────────────
  group('OrganizationRepository.updateMemberRole guardrails', () {
    final repo = OrganizationRepository();

    setUp(() {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'owner-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorCompanyOwner],
      ));
      MockStore.instance.setDemoMembership(Membership(
        uid: 'eng-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      ));
    });

    test('owner can change engineer to procurement', () async {
      final result = await repo.updateMemberRole(
        orgId: 'org-1',
        memberUid: 'eng-1',
        newRole: EnterpriseRole.procurementManager,
        actorUid: 'owner-1',
        orgType: OrganizationType.contractor,
      );
      expect(result.roles, contains(EnterpriseRole.procurementManager));
    });

    test('assigning platformAdmin throws', () {
      expect(
        () => repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'eng-1',
          newRole: EnterpriseRole.platformAdmin,
          actorUid: 'owner-1',
          orgType: OrganizationType.contractor,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('wrong org role for supplier orgType throws', () {
      expect(
        () => repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'eng-1',
          newRole: EnterpriseRole.supplierOps,
          actorUid: 'owner-1',
          orgType: OrganizationType.contractor,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('self-promotion to owner throws', () {
      expect(
        () => repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'eng-1',
          newRole: EnterpriseRole.contractorCompanyOwner,
          actorUid: 'eng-1',
          orgType: OrganizationType.contractor,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('demo: engineer cannot change roles (no actor membership)', () {
      expect(
        () => repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'owner-1',
          newRole: EnterpriseRole.engineer,
          actorUid: 'eng-1',
          orgType: OrganizationType.contractor,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── Project assignment provider ────────────────────────────────────────
  group('ProjectAssignmentRepository', () {
    test('returns empty in demo mode', () async {
      final repo = ProjectAssignmentRepository();
      final list = await repo.watchForProject('proj-1').first;
      expect(list, isEmpty);
    });
  });

  // ─── Contractor screen shows member rows ────────────────────────────────
  testWidgets('contractor screen shows real membership rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final owner = MockStore.demoCustomer;
    MockStore.instance.setDemoMembership(Membership(
      uid: owner.id,
      orgId: 'org-x',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorCompanyOwner],
    ));
    MockStore.instance.setDemoMembership(Membership(
      uid: 'eng-x',
      orgId: 'org-x',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.engineer],
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
                AuthSession(uid: owner.id, profile: owner)),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.contractorCompanyOwner],
            ),
          ),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value([
              Membership(
                uid: owner.id,
                orgId: 'org-x',
                orgType: OrganizationType.contractor,
                roles: const [EnterpriseRole.contractorCompanyOwner],
              ),
            ]),
          ),
          orgMembershipsProvider('org-x').overrideWith(
            (ref) => Stream.value([
              Membership(
                uid: owner.id,
                orgId: 'org-x',
                orgType: OrganizationType.contractor,
                roles: const [EnterpriseRole.contractorCompanyOwner],
              ),
              Membership(
                uid: 'eng-x',
                orgId: 'org-x',
                orgType: OrganizationType.contractor,
                roles: const [EnterpriseRole.engineer],
              ),
            ]),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                  path: '/',
                  builder: (_, __) => const ContractorCompanyScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Navigate to users tab
    await tester.tap(find.text('משתמשים והרשאות'));
    await tester.pumpAndSettle();
    expect(find.byType(MembershipRowCard), findsWidgets);
    // Edit button visible for manager
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
  });

  testWidgets('engineer sees no edit action on contractor screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final eng = MockStore.demoCustomer;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(AuthSession(uid: eng.id, profile: eng)),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.engineer],
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
                  builder: (_, __) => const ContractorCompanyScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Engineer cannot open company management — blocked
    expect(find.text('אין הרשאת ניהול חברה'), findsOneWidget);
  });

  testWidgets('empty state shown when no org members', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final owner = MockStore.demoCustomer;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) =>
                Stream.value(AuthSession(uid: owner.id, profile: owner)),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.contractorCompanyOwner],
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
                  builder: (_, __) => const ContractorCompanyScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('משתמשים והרשאות'));
    await tester.pumpAndSettle();
    expect(find.text('עדיין אין צוות מחובר לחברה'), findsOneWidget);
  });

  // ─── Role change dialog ─────────────────────────────────────────────────
  testWidgets('role change dialog opens and shows description', (tester) async {
    final membership = Membership(
      uid: 'user-1',
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.engineer],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => RoleChangeDialog.show(
                context: ctx,
                membership: membership,
                displayName: 'ישראל ישראלי',
                orgType: OrganizationType.contractor,
                allowedRoles: EnterpriseRoleLabels.contractorAssignableRoles,
                onSave: (_) async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('שינוי תפקיד'), findsOneWidget);
    expect(find.text('ישראל ישראלי'), findsOneWidget);
    expect(find.text('ביטול'), findsOneWidget);
    expect(find.text('שמור שינוי'), findsOneWidget);
  });

  // ─── Project workspace assignments ──────────────────────────────────────
  testWidgets('project workspace shows assignment section', (tester) async {
    final owner = MockStore.instance.currentUser!.id;
    final project = await ProjectRepository().createProject(
      ownerUid: owner,
      name: 'Assignment Site',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(
                  uid: owner, profile: MockStore.instance.currentUser),
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
    expect(find.text('עדיין לא הוגדר צוות לפרויקט'), findsOneWidget);
    expect(find.text('הזמנה חדשה'), findsOneWidget);
  });
}
