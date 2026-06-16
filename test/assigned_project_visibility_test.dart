import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/project.dart';
import 'package:construction_rfq/models/enterprise/project_status.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/models/enterprise/project_assignment.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  group('Project access from memberships + assignments', () {
    const orgId = 'org-1';
    const projectId = 'proj-1';

    void seedProject() {
      final project = Project(
        id: projectId,
        ownerUid: orgId,
        orgId: orgId,
        name: 'אתר בדיקה',
        status: ProjectStatus.active,
        createdBy: orgId,
      );
      MockStore.instance.projects.add(project);
    }

    Membership engineerMembership(String uid) => Membership(
          uid: uid,
          orgId: orgId,
          orgType: OrganizationType.contractor,
          roles: const [EnterpriseRole.engineer],
          status: 'active',
        );

    Membership procurementMembership(String uid) => Membership(
          uid: uid,
          orgId: orgId,
          orgType: OrganizationType.contractor,
          roles: const [EnterpriseRole.procurementManager],
          status: 'active',
        );

    test('engineer assigned to project sees project', () async {
      seedProject();
      const uid = 'eng-1';
      MockStore.instance.setDemoMembership(engineerMembership(uid));
      MockStore.instance.assignUserToProject(
        const ProjectAssignment(
          projectId: projectId,
          orgId: orgId,
          uid: uid,
          role: EnterpriseRole.engineer,
        ),
      );

      final memberships =
          MockStore.instance.membershipsForUser(uid); // demo helper
      final stream = MockStore.instance.watchAccessibleProjects(
        uid: uid,
        memberships: memberships,
      );
      final projects = await stream.first;

      expect(projects.map((p) => p.id), contains(projectId));
    });

    test('procurement assigned to project sees project', () async {
      seedProject();
      const uid = 'proc-1';
      MockStore.instance.setDemoMembership(procurementMembership(uid));
      MockStore.instance.assignUserToProject(
        const ProjectAssignment(
          projectId: projectId,
          orgId: orgId,
          uid: uid,
          role: EnterpriseRole.procurementManager,
        ),
      );

      final memberships = MockStore.instance.membershipsForUser(uid);
      final stream = MockStore.instance.watchAccessibleProjects(
        uid: uid,
        memberships: memberships,
      );
      final projects = await stream.first;

      expect(projects.map((p) => p.id), contains(projectId));
    });

    test('unassigned engineer does not see project', () async {
      seedProject();
      const uid = 'eng-2';
      MockStore.instance.setDemoMembership(engineerMembership(uid));

      final memberships = MockStore.instance.membershipsForUser(uid);
      final stream = MockStore.instance.watchAccessibleProjects(
        uid: uid,
        memberships: memberships,
      );
      final projects = await stream.first;

      expect(projects.map((p) => p.id), isNot(contains(projectId)));
    });

    test('owner sees company org project', () async {
      seedProject();
      const ownerId = orgId;
      MockStore.instance.setDemoMembership(
        Membership(
          uid: ownerId,
          orgId: orgId,
          orgType: OrganizationType.contractor,
          roles: const [EnterpriseRole.contractorCompanyOwner],
          status: 'active',
        ),
      );

      final stream = MockStore.instance.watchAccessibleProjects(
        uid: ownerId,
        memberships: MockStore.instance.membershipsForUser(ownerId),
      );
      final projects = await stream.first;
      expect(projects.map((p) => p.id), contains(projectId));
    });
  });

  group('Engineer permissions matrix', () {
    test('engineer cannot manage projects', () {
      final user = AppUser(
        id: 'eng-1',
        fullName: 'מהנדס',
        email: 'eng@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      );
      final memberships = [
        Membership(
          uid: 'eng-1',
          orgId: 'org-1',
          orgType: OrganizationType.contractor,
          roles: const [EnterpriseRole.engineer],
        ),
      ];

      final perms = EffectivePermissions.resolve(
        user: user,
        memberships: memberships,
      );

      expect(perms, isNot(contains(Permission.manageProjects)));
    });
  });
}
