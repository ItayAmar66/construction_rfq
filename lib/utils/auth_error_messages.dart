import 'package:firebase_auth/firebase_auth.dart';

/// Hebrew copy for Firebase Auth errors in login/register flows.
abstract final class AuthErrorMessages {
  static const wrongCredentials = 'אימייל או סיסמה לא נכונים';
  static const invalidEmail = 'כתובת אימייל לא תקינה';
  static const userExists = 'המשתמש כבר קיים';
  static const weakPassword = 'הסיסמה חלשה מדי';
  static const networkError = 'בעיית חיבור לאינטרנט';
  static const loginFailed = 'לא הצלחנו להתחבר. נסה שוב';

  static String from(Object error) {
    if (error is FirebaseAuthException) {
      return _fromAuthException(error);
    }
    final msg = error.toString();
    if (msg.contains('invalid-credential') ||
        msg.contains('wrong-password') ||
        msg.contains('user-not-found')) {
      return wrongCredentials;
    }
    if (msg.contains('invalid-email')) return invalidEmail;
    if (msg.contains('email-already-in-use')) return userExists;
    if (msg.contains('weak-password')) return weakPassword;
    if (msg.contains('network-request-failed') ||
        msg.contains('network') ||
        msg.contains('Network')) {
      return networkError;
    }
    return loginFailed;
  }

  static String _fromAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return wrongCredentials;
      case 'invalid-email':
        return invalidEmail;
      case 'email-already-in-use':
        return userExists;
      case 'weak-password':
        return weakPassword;
      case 'network-request-failed':
        return networkError;
      default:
        return loginFailed;
    }
  }
}
