import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'hebrew_strings.dart';
import 'auth_error_messages.dart';

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
  return AuthErrorMessages.from(e);
}
