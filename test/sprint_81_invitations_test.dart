import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_invitation.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/enterprise/project_assignment.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/invitation_repository.dart';
import 'package:construction_rfq/repositories/project_assignment_repository.dart';
import 'package:construction_rfq/repositories/project_repository.dart';
import 'package:construction_rfq/screens/contractor/contractor_company_screen.dart';
import 'package:construction_rfq/screens/projects/project_workspace_screen.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/project_assignment_roles.dart';
import 'package:construction_rfq/widgets/permissions/invite_user_dialog.dart';
import 'package:construction_rfq/widgets/permissions/project_team_hierarchy_section.dart';
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
    MockStore.instance.demoMemberships.clear();
    MockStore.instance.demoInvitations.clear();
    MockStore.instance.demoProjectAssignments.clear();
    MockStore.instance.loginAsDemo(UserType.commercialCustomer);
  });

  group('OrganizationInvitation model', () {
    test('serializes and deserializes', () {
      final invite = OrganizationInvitation(
        id: 'inv-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        email: 'eng@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
        createdAt: DateTime(2025, 1, 1),
      );
      final map = invite.toMap();
      final parsed = OrganizationInvitation.fromMap('inv-1', map);
      expect(parsed.email, 'eng@test.local');
      expect(parsed.role, EnterpriseRole.engineer);
      expect(parsed.isPending, isTrue);
    });
  });

  group('InvitationRepository', () {
    test('creates contractor invitation', () async {
      final repo = InvitationRepository();
      final invite = await repo.createInvitation(
        orgId: 'org-c',
        orgType: OrganizationType.contractor,
        email: 'new@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner-1',
        canManage: true,
      );
      expect(invite.status, 'pending');
      expect(invite.orgType, OrganizationType.contractor);
    });

    test('creates supplier invitation', () async {
      final invite = await InvitationRepository().createInvitation(
        orgId: 'org-s',
        orgType: OrganizationType.supplier,
        email: 'rep@test.local',
        role: EnterpriseRole.supplierSalesRep,
        invitedByUid: 'owner-s',
        canManage: true,
      );
      expect(invite.role, EnterpriseRole.supplierSalesRep);
    });

    test('rejects invalid role for org type', () {
      expect(
        () => InvitationRepository().createInvitation(
          orgId: 'org-c',
          orgType: OrganizationType.contractor,
          email: 'x@test.local',
          role: EnterpriseRole.supplierOps,
          invitedByUid: 'owner',
          canManage: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('non-manager cannot create invitation', () {
      expect(
        () => InvitationRepository().createInvitation(
          orgId: 'org-c',
          orgType: OrganizationType.contractor,
          email: 'x@test.local',
          role: EnterpriseRole.engineer,
          invitedByUid: 'eng-1',
          canManage: false,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('matching email can accept invite', () async {
      final repo = InvitationRepository();
      final invite = await repo.createInvitation(
        orgId: 'org-a',
        orgType: OrganizationType.contractor,
        email: 'join@test.local',
        role: EnterpriseRole.procurementManager,
        invitedByUid: 'owner',
        canManage: true,
      );
      final membership = await repo.acceptInvitation(
        inviteId: invite.id,
        uid: 'user-new',
        email: 'join@test.local',
      );
      expect(membership.roles, contains(EnterpriseRole.procurementManager));
      expect(membership.orgId, 'org-a');
    });

    test('different email cannot accept', () async {
      final repo = InvitationRepository();
      final invite = await repo.createInvitation(
        orgId: 'org-a',
        orgType: OrganizationType.contractor,
        email: 'join@test.local',
        role: EnterpriseRole.engineer,
        invitedByUid: 'owner',
        canManage: true,
      );
      expect(
        () => repo.acceptInvitation(
          inviteId: invite.id,
          uid: 'other',
          email: 'wrong@test.local',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ProjectAssignment', () {
    test('serialization', () {
      final a = ProjectAssignment(
        projectId: 'p1',
        orgId: 'org-1',
        uid: 'u1',
        role: EnterpriseRole.engineer,
      );
      final parsed = ProjectAssignment.fromMap(a.toMap());
      expect(parsed.projectId, 'p1');
      expect(parsed.role, EnterpriseRole.engineer);
    });
  });

  group('ProjectAssignmentRepository', () {
    test('assign user to project', () async {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'eng-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      ));
      final repo = ProjectAssignmentRepository();
      final result = await repo.assignUserToProject(
        projectId: 'proj-1',
        orgId: 'org-1',
        uid: 'eng-1',
        role: EnterpriseRole.engineer,
        actorUid: 'owner-1',
        canManage: true,
        orgMembers: MockStore.instance.membershipsForOrg('org-1'),
      );
      expect(result.uid, 'eng-1');
      final list = await repo.watchForProject('proj-1').first;
      expect(list, hasLength(1));
    });

    test('engineer denied assign', () {
      expect(
        () => ProjectAssignmentRepository().assignUserToProject(
          projectId: 'p1',
          orgId: 'org-1',
          uid: 'eng-2',
          role: EnterpriseRole.engineer,
          actorUid: 'eng-1',
          canManage: false,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('remove assignment', () async {
      MockStore.instance.assignUserToProject(ProjectAssignment(
        projectId: 'p2',
        orgId: 'org-1',
        uid: 'u1',
        role: EnterpriseRole.engineer,
      ));
      await ProjectAssignmentRepository().removeProjectAssignment(
        projectId: 'p2',
        uid: 'u1',
        canManage: true,
        actorUid: 'owner-1',
        orgId: 'org-1',
      );
      final list =
          await ProjectAssignmentRepository().watchForProject('p2').first;
      expect(list, isEmpty);
    });
  });

  testWidgets('manager sees add user button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final owner = MockStore.demoCustomer;
    MockStore.instance.setDemoMembership(Membership(
      uid: owner.id,
      orgId: 'org-x',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorCompanyOwner],
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(AuthSession(uid: owner.id, profile: owner)),
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
    await tester.tap(find.text('צוות והרשאות'));
    await tester.pumpAndSettle();
    expect(find.text('הוסף משתמש'), findsOneWidget);
  });

  testWidgets('project team section shows assignments', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    MockStore.instance.setDemoMembership(Membership(
      uid: 'owner',
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorCompanyOwner],
    ));
    MockStore.instance.assignUserToProject(ProjectAssignment(
      projectId: 'proj-team',
      orgId: 'org-1',
      uid: 'eng-1',
      role: EnterpriseRole.engineer,
      displayName: 'Engineer One',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              AuthSession(uid: 'owner', profile: MockStore.demoCustomer),
            ),
          ),
          effectivePermissionsProvider.overrideWith(
            (ref) => EnterprisePermissionService.permissionsForRoles(
              const [EnterpriseRole.contractorCompanyOwner],
            ),
          ),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value([
              Membership(
                uid: 'owner',
                orgId: 'org-1',
                orgType: OrganizationType.contractor,
                roles: const [EnterpriseRole.contractorCompanyOwner],
              ),
              Membership(
                uid: 'eng-1',
                orgId: 'org-1',
                orgType: OrganizationType.contractor,
                roles: const [EnterpriseRole.engineer],
              ),
            ]),
          ),
          orgMembershipsProvider('org-1').overrideWith(
            (ref) => Stream.value([
              Membership(
                uid: 'eng-1',
                orgId: 'org-1',
                orgType: OrganizationType.contractor,
                roles: const [EnterpriseRole.engineer],
              ),
            ]),
          ),
          projectAssignmentsProvider('proj-team').overrideWith(
            (ref) => Stream.value([
              ProjectAssignment(
                projectId: 'proj-team',
                orgId: 'org-1',
                uid: 'eng-1',
                role: EnterpriseRole.engineer,
                displayName: 'Engineer One',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectTeamHierarchySection(
                projectId: 'proj-team',
                orgId: 'org-1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Engineer One'), findsOneWidget);
    expect(find.text('שייך משתמש לפרויקט'), findsOneWidget);
    expect(find.text(ProjectAssignmentRoles.label(EnterpriseRole.engineer)),
        findsOneWidget);
  });

  testWidgets('invite dialog validates email', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => InviteUserDialog.show(
                context: ctx,
                orgType: OrganizationType.contractor,
                allowedRoles: const [
                  EnterpriseRole.engineer,
                  EnterpriseRole.procurementManager,
                ],
                onSubmit: ({required name, required email, required role}) async {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('צור הזמנה'));
    await tester.pumpAndSettle();
    expect(find.text('יש להזין כתובת אימייל תקינה'), findsOneWidget);
  });

  testWidgets('project workspace keeps new order CTA', (tester) async {
    final owner = MockStore.instance.currentUser!.id;
    final project = await ProjectRepository().createProject(
      ownerUid: owner,
      name: 'Team Project',
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
    expect(find.text('הזמנה חדשה'), findsOneWidget);
    expect(find.text('צוות והרשאות בפרויקט'), findsOneWidget);
  });
}
