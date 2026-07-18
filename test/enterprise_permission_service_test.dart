import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

Membership _membership(List<EnterpriseRole> roles) {
  return Membership(
    uid: 'u1',
    orgId: 'org1',
    orgType: OrganizationType.contractor,
    roles: roles,
  );
}

void main() {
  group('EnterprisePermissionService', () {
    test('engineer can draft but not submit RFQ', () {
      final perms =
          EnterprisePermissionService.permissionsForRoles([EnterpriseRole.engineer]);
      expect(perms, contains(Permission.createRfqDraft));
      expect(perms, contains(Permission.editRfqDraft));
      expect(perms, isNot(contains(Permission.submitRfq)));
    });

    test('procurementManager can submit and approve', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.procurementManager],
      );
      expect(perms, contains(Permission.submitRfq));
      expect(perms, contains(Permission.approveQuote));
    });

    test('supplierSalesRep can quote but not ship', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.supplierSales],
      );
      expect(perms, contains(Permission.createSupplierQuote));
      expect(perms, isNot(contains(Permission.markOrderShipped)));
    });

    test('supplierOps can mark shipped', () {
      final perms =
          EnterprisePermissionService.permissionsForRoles([EnterpriseRole.supplierOperations]);
      expect(perms, contains(Permission.markOrderShipped));
      expect(perms, isNot(contains(Permission.createSupplierQuote)));
    });

    test('supplierViewer is read-only', () {
      final perms =
          EnterprisePermissionService.permissionsForRoles([EnterpriseRole.supplierViewer]);
      expect(perms, contains(Permission.viewCatalog));
      expect(perms, isNot(contains(Permission.createSupplierQuote)));
      expect(perms, isNot(contains(Permission.markOrderShipped)));
    });

    test('platformAdmin has all permissions', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.platformAdmin],
      );
      expect(perms.length, Permission.values.length);
    });

    test('membership permissions respect active status', () {
      final inactive = Membership(
        uid: 'u1',
        orgId: 'org1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
        status: 'inactive',
      );
      expect(EnterprisePermissionService.permissionsForMembership(inactive), isEmpty);
      expect(
        EnterprisePermissionService.permissionsForMembership(
          _membership([EnterpriseRole.procurementManager]),
        ),
        isNotEmpty,
      );
    });
  });
}
