import 'app_user.dart';

/// Combined Firebase Auth + Firestore profile state.
class AuthSession {
  const AuthSession({
    this.uid,
    this.profile,
    this.profileMissing = false,
    this.customClaims = const {},
    this.emailVerified = true,
  });

  final String? uid;
  final AppUser? profile;
  final bool profileMissing;
  final Map<String, dynamic> customClaims;

  /// Mirrors the ID token's `email_verified` claim — the same value
  /// firestore.rules' `emailVerified()` checks. Defaults true so demo-mode
  /// and any session built without an explicit value behave as before.
  final bool emailVerified;

  bool get isAuthenticated => uid != null;
  bool get hasProfile => profile != null;

  static const empty = AuthSession();
}
