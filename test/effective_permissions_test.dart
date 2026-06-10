import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _customer() {
  return AppUser(
    id: 'c1',
    fullName: 'קבלן',
    email: 'c@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
  );
}

Membership _membership(EnterpriseRole role) {
  return Membership(
    uid: 'u1',
    orgId: 'org1',
    orgType: OrganizationType.contractor,
    roles: [role],
  );
}

void main() {
  test('legacy commercialCustomer can submit RFQ', () {
    expect(EffectivePermissions.canSubmitRfq(_customer()), isTrue);
  });

  test('engineer membership cannot submit RFQ', () {
    expect(
      EffectivePermissions.canSubmitRfq(
        _customer(),
        memberships: [_membership(EnterpriseRole.engineer)],
      ),
      isFalse,
    );
  });

  test('procurementManager membership can submit RFQ', () {
    expect(
      EffectivePermissions.canSubmitRfq(
        _customer(),
        memberships: [_membership(EnterpriseRole.procurementManager)],
      ),
      isTrue,
    );
  });

  test('supplierSalesRep can submit quote', () {
    final supplier = AppUser(
      id: 's1',
      fullName: 'ספק',
      email: 's@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'חיפה',
      createdAt: DateTime(2026),
    );
    expect(
      EffectivePermissions.canCreateSupplierQuote(
        supplier,
        memberships: [_membership(EnterpriseRole.supplierSalesRep)],
      ),
      isTrue,
    );
  });

  test('supplierOps can mark shipped', () {
    final supplier = AppUser(
      id: 's1',
      fullName: 'ספק',
      email: 's@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'חיפה',
      createdAt: DateTime(2026),
    );
    expect(
      EffectivePermissions.canMarkShipped(
        supplier,
        memberships: [_membership(EnterpriseRole.supplierOps)],
      ),
      isTrue,
    );
  });

  test('viewer cannot write', () {
    expect(
      EffectivePermissions.resolve(
        user: _customer(),
        memberships: [_membership(EnterpriseRole.contractorViewer)],
      ),
      isNot(contains(Permission.submitRfq)),
    );
    expect(
      EffectivePermissions.resolve(
        user: _customer(),
        memberships: [_membership(EnterpriseRole.contractorViewer)],
      ),
      contains(Permission.viewCatalog),
    );
  });
}
