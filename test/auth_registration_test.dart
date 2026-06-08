import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('signup profile creation', () {
    tearDown(() {
      AppMode.isDemoMode = false;
    });

    test('contractor demo register creates readable profile', () {
      AppMode.isDemoMode = true;
      MockStore.instance.init();
      MockStore.instance.registerUser(
        fullName: 'קבלן QA',
        phone: '0501111111',
        email: 'contractor@qa.test',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
      );

      final profile = MockStore.instance.currentUser;
      expect(profile, isNotNull);
      expect(profile!.userType.isCustomer, isTrue);
      expect(profile.fullName, 'קבלן QA');
    });

    test('supplier demo register creates readable profile', () {
      AppMode.isDemoMode = true;
      MockStore.instance.init();
      MockStore.instance.registerUser(
        fullName: 'ספק ענק QA A',
        phone: '0502222222',
        email: 'supplier-a@qa.test',
        userType: UserType.commercialSupplier,
        city: 'חיפה',
      );

      final profile = MockStore.instance.currentUser;
      expect(profile, isNotNull);
      expect(profile!.userType.isSupplier, isTrue);
      expect(profile.fullName, 'ספק ענק QA A');
    });
  });

  group('account role labels', () {
    test('registration labels separate role from subtype', () {
      expect(
        UserType.commercialCustomer.registrationLabel,
        contains('קבלן'),
      );
      expect(
        UserType.commercialSupplier.registrationLabel,
        contains('ספק'),
      );
      expect(UserType.privateCustomer.subtypeLabel, 'קבלן קטן');
      expect(UserType.commercialSupplier.subtypeLabel, 'ספק מסחרי');
    });
  });
}
