import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Demo account copy', () {
    test('demo login labels describe role clearly', () {
      expect(HebrewStrings.demoLoginCustomer, contains('קבלן'));
      expect(HebrewStrings.demoLoginSupplier, contains('ספק'));
    });

    test('demo scenario section explains pre-seeded flows', () {
      expect(HebrewStrings.demoScenarioCompareTitle, isNotEmpty);
      expect(HebrewStrings.demoScenarioCompareHint, contains('קטלוג'));
      expect(HebrewStrings.demoScenarioFulfilledHint, contains('דרך'));
    });

    test('demo mode hint mentions local data', () {
      expect(HebrewStrings.demoModeHint, contains('הדגמה'));
      expect(HebrewStrings.demoModeHint, contains('Firebase'));
    });
  });
}
