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
}
