import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../models/user_type.dart';
import '../utils/constants.dart';
import 'mock_store.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestoreDb => _firestore ?? FirebaseFirestore.instance;

  Stream<String?> get authStateChanges {
    if (AppMode.isDemoMode) return MockStore.instance.authStateChanges;
    return _firebaseAuth.authStateChanges().map((user) {
      if (kDebugMode) {
        debugPrint('[Auth] authStateChanges uid=${user?.uid}');
      }
      return user?.uid;
    });
  }

  /// Live session: Firebase Auth uid + Firestore users/{uid} profile snapshots.
  Stream<AuthSession> watchAuthSession() {
    if (AppMode.isDemoMode) {
      return MockStore.instance.authStateChanges.asyncMap((uid) {
        if (uid == null) return AuthSession.empty;
        return AuthSession(
          uid: uid,
          profile: MockStore.instance.currentUser,
        );
      });
    }

    return _firebaseAuth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        if (kDebugMode) debugPrint('[Auth] no user');
        return Stream.value(AuthSession.empty);
      }

      if (kDebugMode) {
        debugPrint('[Auth] listening profile users/${firebaseUser.uid}');
      }

      return _firestoreDb
          .collection(AppConstants.usersCollection)
          .doc(firebaseUser.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) {
          if (kDebugMode) {
            debugPrint('[Auth] profile MISSING for ${firebaseUser.uid}');
          }
          return AuthSession(
            uid: firebaseUser.uid,
            profileMissing: true,
          );
        }
        final profile = AppUser.fromMap(doc.id, doc.data()!);
        if (kDebugMode) {
          debugPrint('[Auth] profile loaded: ${profile.fullName} (${profile.userType.value})');
        }
        return AuthSession(uid: firebaseUser.uid, profile: profile);
      });
    });
  }

  Future<AppUser?> getUserById(String userId) async {
    if (AppMode.isDemoMode) {
      final user = MockStore.instance.currentUser;
      if (user?.id == userId) return user;
      return null;
    }

    try {
      final doc = await _firestoreDb
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] getUserById error: $e');
      return null;
    }
  }

  Future<AppUser?> getCurrentAppUser() async {
    if (AppMode.isDemoMode) return MockStore.instance.currentUser;

    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestoreDb
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] getCurrentAppUser error: $e');
      throw Exception(FirebaseErrorHelper.toHebrewMessage(e));
    }
  }

  Future<void> loginAsDemo(UserType userType) async {
    AppMode.enableDemoMode();
    MockStore.instance.loginAsDemo(userType);
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required UserType userType,
    required String city,
    String? notes,
  }) async {
    if (AppMode.isDemoMode) {
      MockStore.instance.registerUser(
        fullName: fullName,
        phone: phone,
        email: email,
        userType: userType,
        city: city,
        notes: notes,
      );
      return;
    }

    try {
      if (kDebugMode) debugPrint('[Auth] register: $email');
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final appUser = AppUser(
        id: uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        userType: userType,
        city: city.trim(),
        notes: notes?.trim(),
        createdAt: DateTime.now(),
      );
      await _firestoreDb
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(appUser.toRegistrationMap());
      if (kDebugMode) debugPrint('[Auth] profile saved users/$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] register error: $e');
      throw Exception(_mapError(e));
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (AppMode.isDemoMode) {
      throw Exception('במצב הדגמה השתמש בכפתורי ההתחברות לדוגמה');
    }

    try {
      if (kDebugMode) debugPrint('[Auth] login: $email');
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] login error: $e');
      throw Exception(_mapError(e));
    }
  }

  Future<void> logout() async {
    if (AppMode.isDemoMode) {
      MockStore.instance.logout();
      return;
    }
    if (kDebugMode) debugPrint('[Auth] logout');
    await _firebaseAuth.signOut();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String city,
    String? notes,
  }) async {
    if (AppMode.isDemoMode) {
      MockStore.instance.updateProfile(
        fullName: fullName,
        phone: phone,
        city: city,
        notes: notes,
      );
      return;
    }

    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) throw Exception('לא מחובר');

    await _firestoreDb.collection(AppConstants.usersCollection).doc(uid).update({
      'name': fullName.trim(),
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'notes': notes?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _mapError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use')) {
      return 'האימייל כבר רשום במערכת';
    }
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'אימייל או סיסמה שגויים';
    }
    if (msg.contains('invalid-email')) return 'כתובת אימייל לא תקינה';
    if (msg.contains('weak-password')) return 'סיסמה חלשה מדי';
    return FirebaseErrorHelper.toHebrewMessage(e);
  }
}
