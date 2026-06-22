import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/services/quote_persistence_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intentional Hebrew business exceptions are not genericized', () {
    final duplicate = Exception('כבר נשלחה הצעה מטעם הספק הזה לבקשה זו');
    expect(isIntentionalQuoteBusinessException(duplicate), isTrue);
    expect(
      FirebaseErrorHelper.toHebrewMessage(duplicate),
      'אירעה שגיאה בטעינת הנתונים. נסה שוב מאוחר יותר.',
    );
  });

  test('firebase exceptions stay on firebase error path', () {
    final denied = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
    expect(isIntentionalQuoteBusinessException(denied), isFalse);
    expect(
      FirebaseErrorHelper.toHebrewMessage(denied),
      'אין הרשאה לגשת לנתונים. בדוק את כללי Firestore.',
    );
  });
}
