import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/access_request.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../models/enterprise/organization_type.dart';
import '../models/user_type.dart';
import '../repositories/access_request_repository.dart';
import '../utils/constants.dart';
import '../utils/auth_error_messages.dart';
import 'mock_store.dart';
import 'quote_persistence_support.dart';

/// Plain-Dart projection of the bit of `DocumentSnapshot` that
/// [authSessionFromProfileStream] needs. `DocumentSnapshot` itself is
/// sealed (cannot be implemented/faked outside cloud_firestore), so this
/// small value type is the seam that keeps the stream-transform logic
/// unit-testable without a real Firestore instance.
@visibleForTesting
class ProfileDocEvent {
  const ProfileDocEvent({required this.exists, required this.id, this.data});

  factory ProfileDocEvent.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      ProfileDocEvent(exists: doc.exists, id: doc.id, data: doc.data());

  final bool exists;
  final String id;
  final Map<String, dynamic>? data;
}

/// Turns a raw `users/{uid}` profile-doc stream into an [AuthSession]
/// stream, safely.
///
/// A plain `.handleError(...).asyncMap(...)` chain swallows a
/// permission-denied event without emitting anything downstream: the
/// StreamProvider is then left holding whatever [AuthSession] it last
/// emitted (e.g. a fully-authenticated one) forever, so a disabled account
/// or revoked membership never reaches the router. This instead treats
/// permission-denied as a real, terminal event that emits
/// [AuthSession.empty] — the same "signed out" state the router already
/// redirects on — and then closes the sink so we stop listening on what is,
/// under Firestore security rules, a dead subscription (no reconnect loop).
/// Any other error is passed through unchanged.
@visibleForTesting
Stream<AuthSession> authSessionFromProfileStream({
  required String uid,
  required Stream<ProfileDocEvent> profileSnapshots,
  required Future<Map<String, dynamic>> Function() loadClaims,
}) {
  Future<AuthSession> buildSession(ProfileDocEvent doc) async {
    final claims = await loadClaims();

    // firestore.rules' emailVerified() reads this exact ID-token claim, so
    // it — not the (possibly stale-cached) User.emailVerified getter — is
    // the source of truth for whether a write like invite-accept will be
    // allowed.
    final emailVerified = claims['email_verified'] == true;

    if (!doc.exists || doc.data == null) {
      if (kDebugMode) debugPrint('[Auth] profile MISSING for $uid');
      return AuthSession(
        uid: uid,
        profileMissing: true,
        customClaims: claims,
        emailVerified: emailVerified,
      );
    }
    final profile = AppUser.fromMap(doc.id, doc.data!);
    if (kDebugMode) {
      debugPrint('[Auth] profile loaded: ${profile.fullName} (${profile.userType.value})');
    }
    return AuthSession(
      uid: uid,
      profile: profile,
      customClaims: claims,
      emailVerified: emailVerified,
    );
  }

  return profileSnapshots.transform(
    StreamTransformer<ProfileDocEvent, AuthSession>.fromHandlers(
      handleData: (doc, sink) {
        buildSession(doc).then(sink.add, onError: sink.addError);
      },
      handleError: (Object error, StackTrace stackTrace, sink) {
        if (isFirestorePermissionDenied(error)) {
          if (kDebugMode) {
            debugPrint(
              '[Auth] profile read permission-denied for $uid -> emitting empty session',
            );
          }
          sink.add(AuthSession.empty);
          sink.close();
          return;
        }
        sink.addError(error, stackTrace);
      },
    ),
  );
}

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

      return authSessionFromProfileStream(
        uid: firebaseUser.uid,
        profileSnapshots: _firestoreDb
            .collection(AppConstants.usersCollection)
            .doc(firebaseUser.uid)
            .snapshots()
            .map(ProfileDocEvent.fromSnapshot),
        loadClaims: () async {
          try {
            final token = await firebaseUser.getIdTokenResult().timeout(
                  const Duration(seconds: 8),
                );
            return Map<String, dynamic>.from(token.claims ?? const {});
          } catch (e) {
            if (kDebugMode) debugPrint('[Auth] claims load error: $e');
            return const {};
          }
        },
      );
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
    required String requestedCompanyName,
    String? requestedRole,
    String? requestedProjectName,
  }) async {
    if (AppMode.isDemoMode) {
      MockStore.instance.registerUser(
        fullName: fullName,
        phone: phone,
        email: email,
        userType: userType,
        city: city,
        notes: notes,
        requestedCompanyName: requestedCompanyName,
      );
      return;
    }

    User? createdUser;
    try {
      if (kDebugMode) debugPrint('[Auth] register: $email');
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = credential.user;
      final uid = createdUser!.uid;
      final requestedOrgType =
          userType.isSupplier ? OrganizationType.supplier : OrganizationType.contractor;
      final accessRepo = AccessRequestRepository(firestore: _firestoreDb);
      // Firestore rules only allow listing `organizations` once the caller's
      // own `users/{uid}` doc exists (see isCustomer()/userPendingApproval()
      // in firestore.rules), but that doc is written further below — so this
      // lookup is always denied for brand-new registrants. Treat denial as
      // "no match found" rather than aborting the whole registration; an
      // admin can still link the org manually during access-request review.
      String? matchedOrgId;
      try {
        matchedOrgId = await accessRepo.resolveOrgIdByName(
          companyName: requestedCompanyName,
          type: requestedOrgType,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Auth] resolveOrgIdByName failed, continuing without match: $e');
        }
      }
      final appUser = AppUser(
        id: uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        userType: userType,
        city: city.trim(),
        notes: notes?.trim(),
        createdAt: DateTime.now(),
        requestedOrgName: requestedCompanyName.trim(),
        requestedOrgType: requestedOrgType.value,
        requestedOrgId: matchedOrgId,
        requestedRole: requestedRole,
        requestedProjectName: requestedProjectName,
      );
      await _firestoreDb.collection(AppConstants.usersCollection).doc(uid).set(
            appUser.toRegistrationMap(
              requestedOrgId: matchedOrgId,
              requestedOrgName: requestedCompanyName.trim(),
              requestedOrgType: requestedOrgType.value,
              requestedRole: requestedRole,
              requestedProjectName: requestedProjectName,
            ),
          );
      await accessRepo.createPendingRequest(
        AccessRequest(
          uid: uid,
          email: email.trim().toLowerCase(),
          fullName: fullName.trim(),
          userType: userType.value,
          requestedOrgType: requestedOrgType,
          requestedOrgId: matchedOrgId ?? '',
          requestedOrgName: requestedCompanyName.trim(),
          requestedRole: requestedRole ?? '',
          requestedProjectName: requestedProjectName ?? '',
        ),
      );
      // Send an address-ownership proof. Firestore rules require a verified
      // email before an org invitation can be accepted (see emailVerified() in
      // firestore.rules), which prevents an attacker from registering a
      // victim's invited address to join their organization. Best-effort: a
      // delivery failure must not abort registration.
      try {
        await createdUser.sendEmailVerification();
      } catch (verifyError) {
        if (kDebugMode) {
          debugPrint('[Auth] sendEmailVerification failed: $verifyError');
        }
      }
      await waitForProfileDocument(uid);
      if (kDebugMode) debugPrint('[Auth] profile saved users/$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] register error: $e');
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (deleteError) {
          if (kDebugMode) {
            debugPrint('[Auth] rollback auth user failed: $deleteError');
          }
        }
      }
      throw Exception(AuthErrorMessages.from(e));
    }
  }

  /// Resends the Firebase email-verification link to the signed-in user.
  Future<void> resendVerificationEmail() async {
    if (AppMode.isDemoMode) return;
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('לא מחובר');
    try {
      await user.sendEmailVerification().timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] resend verification error: $e');
      throw Exception(AuthErrorMessages.from(e));
    }
  }

  /// Forces a fresh ID token (so `email_verified` reflects a just-clicked
  /// verification link) and returns whether the address is now verified.
  Future<bool> refreshVerificationStatus() async {
    if (AppMode.isDemoMode) return true;
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    try {
      await user.reload().timeout(const Duration(seconds: 8));
      final refreshed = _firebaseAuth.currentUser;
      if (refreshed == null) return false;
      final token = await refreshed
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 8));
      return token.claims?['email_verified'] == true || refreshed.emailVerified;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] refresh verification error: $e');
      return false;
    }
  }

  /// Waits until users/{uid} exists (post-register or recovery).
  Future<void> waitForProfileDocument(
    String uid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final doc = await _firestoreDb
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw Exception(
      'פרופיל המשתמש לא נטען מהשרת. נסה שוב או פנה לתמיכה.',
    );
  }

  /// Creates a missing Firestore profile for the signed-in Auth user.
  Future<AppUser> completeMissingProfile({
    required UserType userType,
    required String fullName,
    required String phone,
    required String city,
    String? notes,
  }) async {
    if (AppMode.isDemoMode) {
      throw Exception('במצב הדגמה השתמש בהרשמה רגילה');
    }

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) throw Exception('לא מחובר');

    final ref = _firestoreDb
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid);
    final existing = await ref.get();
    if (existing.exists && existing.data() != null) {
      return AppUser.fromMap(existing.id, existing.data()!);
    }

    final email = firebaseUser.email?.trim() ?? '';
    if (email.isEmpty) {
      throw Exception('חסר אימייל בחשבון ההתחברות');
    }

    final appUser = AppUser(
      id: firebaseUser.uid,
      fullName: fullName.trim(),
      email: email,
      phone: phone.trim(),
      userType: userType,
      city: city.trim(),
      notes: notes?.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await ref.set(appUser.toRegistrationMap());
      await waitForProfileDocument(firebaseUser.uid);
      return appUser;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] completeMissingProfile error: $e');
      throw Exception(AuthErrorMessages.from(e));
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
      throw Exception(AuthErrorMessages.from(e));
    }
  }

  /// Sends a Firebase password-reset email. Additive standard flow — does not
  /// alter existing sign-in/registration behaviour.
  Future<void> sendPasswordResetEmail(String email) async {
    if (AppMode.isDemoMode) {
      throw Exception('במצב הדגמה איפוס סיסמה אינו זמין');
    }
    try {
      if (kDebugMode) debugPrint('[Auth] password reset: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] password reset error: $e');
      throw Exception(AuthErrorMessages.from(e));
    }
  }

  Future<void> logout() async {
    if (AppMode.isDemoMode) {
      MockStore.instance.logout();
      return;
    }
    if (kDebugMode) debugPrint('[Auth] logout');
    await _firebaseAuth.signOut();
    try {
      await _firebaseAuth
          .authStateChanges()
          .firstWhere((user) => user == null)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      if (_firebaseAuth.currentUser == null) return;
    }
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
}
