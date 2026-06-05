import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/utils/role_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(UserType type) {
  return AppUser(
    id: 'u1',
    fullName: 'User',
    email: 'u@test.com',
    phone: '050',
    userType: type,
    city: 'TLV',
    createdAt: DateTime(2024),
  );
}

void main() {
  test('commercial customer can approve quotes', () {
    final user = _user(UserType.commercialCustomer);
    expect(RolePermissions.canCreateRequest(user), isTrue);
    expect(RolePermissions.canApproveQuote(user), isTrue);
    expect(RolePermissions.canManageCatalog(user), isFalse);
  });

  test('supplier can respond but not approve', () {
    final user = _user(UserType.commercialSupplier);
    expect(RolePermissions.canRespondToRfq(user), isTrue);
    expect(RolePermissions.canApproveQuote(user), isFalse);
  });
}
