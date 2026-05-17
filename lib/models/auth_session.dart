import 'app_user.dart';

/// Combined Firebase Auth + Firestore profile state.
class AuthSession {
  const AuthSession({
    this.uid,
    this.profile,
    this.profileMissing = false,
  });

  final String? uid;
  final AppUser? profile;
  final bool profileMissing;

  bool get isAuthenticated => uid != null;
  bool get hasProfile => profile != null;

  static const empty = AuthSession();
}
