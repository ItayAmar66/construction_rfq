import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/repositories/admin_management_repository.dart';
import 'package:construction_rfq/services/admin_management_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/platform_admin.dart';
import 'package:construction_rfq/services/supplier_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    AdminManagementRepository.resetDemoStores();
  });

  group('AdminManagementService demo CRUD', () {
    late AdminManagementService service;

    setUp(() {
      service = AdminManagementService();
    });

    test('admin can create contractor org', () async {
      final org = await service.createContractorCompany(name: 'דימרי');
      expect(org.type, OrganizationType.contractor);
      expect(org.status, 'active');
      expect(org.name, 'דימרי');

      final orgs = await service.fetchOrganizations();
      expect(orgs.any((o) => o.id == org.id), isTrue);
    });

    test('admin can create supplier org', () async {
      final org = await service.createSupplierCompany(
        name: 'פרישמן',
        city: 'תל אביב',
        ownerUid: 'supplier-owner-1',
      );
      expect(org.type, OrganizationType.supplier);
      expect(org.status, 'active');
    });

    test('admin can create project with assignments', () async {
      final contractor = await service.createContractorCompany(name: 'אפגד');
      final project = await service.createProject(
        name: 'פרויקט א',
        orgId: contractor.id,
        ownerUid: 'owner-1',
        actorUid: 'admin-1',
        location: 'חיפה',
        assignees: {
          EnterpriseRole.procurementManager: 'proc-1',
          EnterpriseRole.engineer: 'eng-1',
        },
      );
      expect(project.name, 'פרויקט א');
      expect(MockStore.instance.projects.any((p) => p.id == project.id), isTrue);
      expect(
        MockStore.instance.projectAssignmentsFor(project.id).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('admin can create membership', () async {
      final org = await service.createContractorCompany(name: 'שריקי');
      final membership = await service.assignMembership(
        orgId: org.id,
        orgType: OrganizationType.contractor,
        uid: 'user-proc-1',
        role: EnterpriseRole.procurementManager,
        actorUid: 'admin-1',
        email: 'proc@test.com',
        displayName: 'רכש',
      );
      expect(membership.status, 'active');
      expect(membership.roles, contains(EnterpriseRole.procurementManager));
    });

    test('created supplier appears in supplier picker list', () async {
      await service.createSupplierCompany(name: 'טובול', ownerUid: 'tubul-owner');
      final suppliers = await SupplierDirectoryService().listSuppliers();
      expect(suppliers.any((s) => s.fullName.contains('טובול')), isTrue);
    });

    test('created contractor project visible via mock assignments', () async {
      final org = await service.createContractorCompany(name: 'דימרי');
      final project = await service.createProject(
        name: 'דימרי P1',
        orgId: org.id,
        ownerUid: 'dimri-owner',
        actorUid: 'admin-1',
        assignees: {EnterpriseRole.engineer: 'dimri-eng'},
      );
      final assignments = MockStore.instance.projectAssignmentsFor(project.id);
      expect(assignments.any((a) => a.uid == 'dimri-eng'), isTrue);
    });
  });

  group('Non-admin access', () {
    test('platform admin claim required for admin nav permission', () {
      expect(PlatformAdmin.fromCustomClaims({}), isFalse);
      expect(
        PlatformAdmin.fromCustomClaims({PlatformAdmin.claimKey: true}),
        isTrue,
      );
    });

    test('create user command does not embed service account', () {
      final service = AdminManagementService();
      final cmd = service.buildCreateUserCommand(
        email: 'dimri.owner@test.com',
        password: '123123',
        fullName: 'דימרי בעלים',
        orgId: 'launch-org-dimri',
        role: EnterpriseRole.contractorCompanyOwner,
        orgType: OrganizationType.contractor,
      );
      expect(cmd.command, contains('admin_onboarding.js create-user'));
      expect(cmd.command, isNot(contains('serviceAccount')));
      expect(cmd.command, isNot(contains('private_key')));
    });
  });
}
