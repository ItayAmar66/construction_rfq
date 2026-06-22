import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final supplierOwner = AppUser(
    id: 'DRy60MnQjwPQCe6ARmf08cqGsM12',
    fullName: 'QA מנהל ספק גדול',
    email: 'qa.supplier.big.owner@test.com',
    phone: '050',
    userType: UserType.commercialSupplier,
    city: 'תל אביב',
    createdAt: DateTime(2026),
    supplierOrgId: 'DRy60MnQjwPQCe6ARmf08cqGsM12',
  );

  test('supplier owner keeps quote permission from profile org without memberships',
      () {
    final perms = EffectivePermissions.resolve(user: supplierOwner);
    expect(perms, contains(Permission.createSupplierQuote));
    expect(perms, contains(Permission.markShipped));
  });

  test('supplier without org id still only has catalog when memberships empty', () {
    final perms = EffectivePermissions.resolve(
      user: AppUser(
        id: 'orphan-supplier',
        fullName: 'Orphan',
        email: 'o@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      ),
    );
    expect(perms, {Permission.viewCatalog});
  });

  test('supplier profile org grants platform access without memberships', () {
    final user = AppUser(
      id: 'sup-1',
      fullName: 'ספק',
      email: 's@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'תל אביב',
      createdAt: DateTime(2026),
      supplierOrgId: 'qa-org-supplier-a',
    );
    expect(
      EffectivePermissions.hasPlatformAccess(user: user),
      isTrue,
    );
  });

  test('contractor profile org grants platform access without memberships', () {
    final user = AppUser(
      id: 'eng-1',
      fullName: 'מהנדס',
      email: 'eng@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'תל אביב',
      createdAt: DateTime(2026),
      supplierOrgId: 'qa-org-contractor-alpha',
    );
    expect(
      EffectivePermissions.hasPlatformAccess(user: user),
      isTrue,
    );
  });
}
