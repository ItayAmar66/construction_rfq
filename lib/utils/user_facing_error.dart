import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'hebrew_strings.dart';

/// Strips wrapper noise and maps Firebase errors to clean Hebrew UI copy.
String userFacingError(Object error) {
  if (error is FirebaseException) {
    return _firebaseExceptionMessage(error);
  }
  if (error is FirebaseAuthException) {
    return _authExceptionMessage(error);
  }

  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  if (text.contains('[cloud_firestore/permission-denied]')) {
    return 'אין הרשאה לפעולה זו';
  }
  if (text.contains('network') || text.contains('Network')) {
    return 'בדוק חיבור לאינטרנט ונסה שוב';
  }
  if (text.contains('unavailable') || text.contains('Unavailable')) {
    return 'השירות אינו זמין כרגע. נסה שוב.';
  }
  return text.length > 120 ? HebrewStrings.errorGeneric : text;
}

String _firebaseExceptionMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'אין הרשאה לפעולה זו';
    case 'unavailable':
      return 'השירות אינו זמין כרגע. נסה שוב.';
    case 'not-found':
      return 'הפריט לא נמצא';
    case 'already-exists':
      return 'הפריט כבר קיים';
    case 'failed-precondition':
      return 'לא ניתן לבצע את הפעולה במצב הנוכחי';
    default:
      return HebrewStrings.errorGeneric;
  }
}

String _authExceptionMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'אימייל או סיסמה שגויים';
    case 'invalid-email':
      return 'כתובת אימייל לא תקינה';
    case 'email-already-in-use':
      return 'כתובת האימייל כבר בשימוש';
    case 'weak-password':
      return 'הסיסמה חלשה מדי';
    case 'network-request-failed':
      return 'בדוק חיבור לאינטרנט ונסה שוב';
    default:
      return HebrewStrings.errorGeneric;
  }
}
