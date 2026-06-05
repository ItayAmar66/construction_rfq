import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/utils/supplier_capability_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile exposes categories and service areas', () {
    final user = AppUser(
      id: 's1',
      fullName: 'Supplier',
      email: 's@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'חיפה',
      createdAt: DateTime(2024),
      supplierCategoryIds: const ['7', '9'],
      serviceAreas: const ['תל אביב', 'חיפה'],
    );

    final profile = SupplierCapabilityHelpers.profileFor(user);
    expect(profile.hasCategories, isTrue);
    expect(profile.categoriesLabel, contains('7'));
    expect(SupplierCapabilityHelpers.servesCity(
      supplier: user,
      city: 'תל אביב',
    ), isTrue);
  });
}
