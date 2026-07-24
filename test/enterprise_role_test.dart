import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnterpriseRole.fromValue', () {
    test('null and unknown values yield null (no silent default)', () {
      expect(EnterpriseRole.fromValue(null), isNull);
      expect(EnterpriseRole.fromValue('not-a-role'), isNull);
      expect(EnterpriseRole.fromValue(''), isNull);
    });

    test('round-trips every enum value', () {
      for (final role in EnterpriseRole.values) {
        expect(EnterpriseRole.fromValue(role.value), role);
      }
    });
  });

  group('role partitions', () {
    test('contractor roles are classified as contractor only', () {
      const contractorRoles = [
        EnterpriseRole.contractorCompanyOwner,
        EnterpriseRole.procurementManager,
        EnterpriseRole.projectManager,
        EnterpriseRole.engineer,
        EnterpriseRole.contractorViewer,
      ];
      for (final role in contractorRoles) {
        expect(role.isContractorRole, isTrue, reason: '$role');
        expect(role.isSupplierRole, isFalse, reason: '$role');
      }
    });

    test('supplier roles are classified as supplier only', () {
      const supplierRoles = [
        EnterpriseRole.supplierOwner,
        EnterpriseRole.supplierSalesManager,
        EnterpriseRole.supplierSalesRep,
        EnterpriseRole.supplierOps,
        EnterpriseRole.supplierViewer,
      ];
      for (final role in supplierRoles) {
        expect(role.isSupplierRole, isTrue, reason: '$role');
        expect(role.isContractorRole, isFalse, reason: '$role');
      }
    });

    test('platformAdmin belongs to neither org partition', () {
      expect(EnterpriseRole.platformAdmin.isContractorRole, isFalse);
      expect(EnterpriseRole.platformAdmin.isSupplierRole, isFalse);
    });
  });
}
