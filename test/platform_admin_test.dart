import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:construction_rfq/services/platform_admin.dart';
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

void main() {
  test('normal user is not platform admin', () {
    expect(PlatformAdmin.fromCustomClaims({}), isFalse);
    expect(PlatformAdmin.fromCustomClaims({'userType': 'admin'}), isFalse);
  });

  test('platformAdmin claim grants all permissions', () {
    final perms = EffectivePermissions.resolve(
      user: _customer(),
      customClaims: {PlatformAdmin.claimKey: true},
    );
    expect(perms.length, Permission.values.length);
  });

  test('userType profile alone does not grant platform admin', () {
    final user = AppUser(
      id: 'x',
      fullName: 'Fake',
      email: 'x@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'x',
      createdAt: DateTime(2026),
      notes: 'admin',
    );
    expect(
      EffectivePermissions.isPlatformAdmin({'userType': 'admin'}),
      isFalse,
    );
    expect(
      EffectivePermissions.resolve(user: user).contains(Permission.platformManageAll),
      isFalse,
    );
  });
}
