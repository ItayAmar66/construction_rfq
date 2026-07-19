import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/enterprise/project.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/project_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/repositories/project_assignment_repository.dart';
import 'package:construction_rfq/utils/shipment_receipt_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for Phase 4 #2/#3: permission providers that take an
/// org/project as context must scope to THAT org, not union permissions
/// across every org the user belongs to (effectivePermissionsProvider).
void main() {
  final user = AppUser(
    id: 'user-1',
    fullName: 'משתמש רב-ארגוני',
    email: 'multi@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
  );

  // Owner in org-a, mere viewer in org-b — a real multi-org membership set.
  final memberships = [
    Membership(
      uid: 'user-1',
      orgId: 'org-a',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorOwner],
    ),
    Membership(
      uid: 'user-1',
      orgId: 'org-b',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorViewer],
    ),
  ];

  ProviderContainer buildContainer({List<Override> extra = const []}) {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(AuthSession(uid: user.id, profile: user)),
        ),
        currentUserMembershipsProvider.overrideWith(
          (ref) => Stream.value(memberships),
        ),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // StreamProvider overrides (even Stream.value(...)) deliver their first
  // event on a microtask, not synchronously — container.read() right after
  // construction would see the pre-data (loading) state. Await the futures
  // this test relies on first so reads below see the real override data.
  Future<void> settle(ProviderContainer container) async {
    await container.read(authSessionProvider.future);
    await container.read(currentUserMembershipsProvider.future);
  }

  group('effectivePermissionsForOrgProvider', () {
    test('grants owner-level permissions for the org the user owns', () async {
      final container = buildContainer();
      await settle(container);
      final perms = container.read(effectivePermissionsForOrgProvider('org-a'));
      expect(perms.contains(Permission.manageUsers), isTrue);
      expect(perms.contains(Permission.manageProjects), isTrue);
    });

    test('does NOT leak owner permissions into a different org membership',
        () async {
      final container = buildContainer();
      await settle(container);
      final perms = container.read(effectivePermissionsForOrgProvider('org-b'));
      expect(perms.contains(Permission.manageUsers), isFalse);
      expect(perms.contains(Permission.manageProjects), isFalse);
    });

    test('the old global provider still unions across orgs (contrast case)',
        () async {
      final container = buildContainer();
      await settle(container);
      final perms = container.read(effectivePermissionsProvider);
      // This is the exact drift effectivePermissionsForOrgProvider exists to
      // avoid for org/project-scoped checks: manageUsers leaks in globally
      // even though it only applies to org-a.
      expect(perms.contains(Permission.manageUsers), isTrue);
    });

    test('unknown org yields no elevated permissions', () async {
      final container = buildContainer();
      await settle(container);
      final perms =
          container.read(effectivePermissionsForOrgProvider('org-unrelated'));
      expect(perms.contains(Permission.manageUsers), isFalse);
    });
  });

  group('canManageProjectTeamProvider org scoping', () {
    test('org-a project: owner can manage; org-b project: viewer cannot',
        () async {
      final container = buildContainer(extra: [
        projectAssignmentsProvider
            .overrideWith((ref, projectId) => Stream.value(const [])),
      ]);
      await settle(container);
      await container.read(projectAssignmentsProvider('proj-1').future);
      await container.read(projectAssignmentsProvider('proj-2').future);
      expect(
        container.read(canManageProjectTeamProvider(
          (projectId: 'proj-1', orgId: 'org-a'),
        )),
        isTrue,
      );
      expect(
        container.read(canManageProjectTeamProvider(
          (projectId: 'proj-2', orgId: 'org-b'),
        )),
        isFalse,
      );
    });
  });

  group('project ownership providers (canCompleteProjectProvider/canDeleteProjectProvider)',
      () {
    test('project owner can complete/delete their own project', () async {
      final container = buildContainer(extra: [
        projectProvider.overrideWith(
          (ref, projectId) => Stream.value(
            Project(
              id: projectId,
              name: 'פרויקט שלי',
              ownerUid: user.id,
              orgId: 'org-a',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ),
      ]);
      await settle(container);
      await container.read(projectProvider('proj-1').future);
      expect(container.read(canCompleteProjectProvider('proj-1')), isTrue);
      expect(container.read(canDeleteProjectProvider('proj-1')), isTrue);
    });

    test('an org admin who does not own the project cannot complete/delete it',
        () async {
      // user-1 is contractorOwner (manageProjects) in org-a, but this
      // project is owned by someone else — server rule is pure ownerUid,
      // not org role, so this must be false despite the org permission.
      final container = buildContainer(extra: [
        projectProvider.overrideWith(
          (ref, projectId) => Stream.value(
            Project(
              id: projectId,
              name: 'פרויקט של מישהו אחר',
              ownerUid: 'someone-else',
              orgId: 'org-a',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ),
        ),
      ]);
      await settle(container);
      await container.read(projectProvider('proj-1').future);
      expect(container.read(canCompleteProjectProvider('proj-1')), isFalse);
      expect(container.read(canDeleteProjectProvider('proj-1')), isFalse);
    });
  });

  group('ShipmentReceiptAccess live project assignee override', () {
    QuoteRequest request({String? projectId}) => QuoteRequest(
          id: 'req-1',
          customerId: 'customer-1',
          customerName: 'לקוח',
          customerPhone: '050',
          customerCity: 'תל אביב',
          customerType: 'commercialCustomer',
          status: QuoteRequestStatus.pendingReceipt,
          items: const [],
          createdAt: DateTime(2026),
          contractorOrgId: 'org-a',
          projectId: projectId,
        );

    final engineerMembership = Membership(
      uid: 'eng-1',
      orgId: 'org-a',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.engineer],
      projectIds: const [], // stale cache: sync never landed
    );

    test('stale cache blocks access when no live data is supplied (baseline)',
        () {
      expect(
        ShipmentReceiptAccess.canConfirmReceiptForRequest(
          actorUid: 'eng-1',
          request: request(projectId: 'proj-1'),
          memberships: [engineerMembership],
          orgId: 'org-a',
        ),
        isFalse,
      );
    });

    test('live assignment data overrides a stale/empty projectIds cache', () {
      expect(
        ShipmentReceiptAccess.canConfirmReceiptForRequest(
          actorUid: 'eng-1',
          request: request(projectId: 'proj-1'),
          memberships: [engineerMembership],
          orgId: 'org-a',
          liveProjectAssigneeUids: {'eng-1'},
        ),
        isTrue,
      );
    });

    test('live assignment data correctly denies a removed teammate even if '
        'the cache still (incorrectly) lists them', () {
      final staleCacheMembership = Membership(
        uid: 'eng-1',
        orgId: 'org-a',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
        projectIds: const ['proj-1'], // stale: cache never got the removal
      );
      expect(
        ShipmentReceiptAccess.canConfirmReceiptForRequest(
          actorUid: 'eng-1',
          request: request(projectId: 'proj-1'),
          memberships: [staleCacheMembership],
          orgId: 'org-a',
          liveProjectAssigneeUids: <String>{}, // live: no longer assigned
        ),
        isFalse,
      );
    });
  });
}
