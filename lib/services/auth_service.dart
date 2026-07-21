import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_mode.dart';
import '../models/access_request.dart';
import '../models/account_status.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../models/enterprise/organization_type.dart';
import '../models/user_type.dart';
import '../repositories/access_request_repository.dart';
import '../utils/constants.dart';
import '../utils/auth_error_messages.dart';
import 'mock_store.dart';
import 'quote_persistence_support.dart';

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
          .handleError((Object error, StackTrace stackTrace) {
            if (isFirestorePermissionDenied(error)) {
              if (kDebugMode) {
                debugPrint('[Auth] profile read permission-denied');
              }
              return;
            }
            throw error;
          })
          .asyncMap((doc) async {
        Map<String, dynamic> claims = const {};
        try {
          // Force-refresh: platformAdmin (and other custom claims)
          // revocation/grant must take effect promptly, not after the SDK's
          // own up-to-~1-hour token refresh cycle.
          final token = await firebaseUser.getIdTokenResult(true).timeout(
                const Duration(seconds: 8),
              );
          claims = Map<String, dynamic>.from(token.claims ?? const {});
        } catch (e) {
          if (kDebugMode) debugPrint('[Auth] claims load error: $e');
        }

        if (!doc.exists || doc.data() == null) {
          if (kDebugMode) {
            debugPrint('[Auth] profile MISSING for ${firebaseUser.uid}');
          }
          return AuthSession(
            uid: firebaseUser.uid,
            profileMissing: true,
            customClaims: claims,
          );
        }
        final profile = AppUser.fromMap(doc.id, doc.data()!);
        if (kDebugMode) {
          debugPrint('[Auth] profile loaded: ${profile.fullName} (${profile.userType.value})');
        }
        return AuthSession(
          uid: firebaseUser.uid,
          profile: profile,
          customClaims: claims,
        );
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
    final accessRepo = AccessRequestRepository(firestore: _firestoreDb);
    AccessRequest? pendingAccessRequest;
    var profileWritten = false;
    var accessRequestWritten = false;
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
      final matchedOrgId = await accessRepo.resolveOrgIdByName(
        companyName: requestedCompanyName,
        type: requestedOrgType,
      );
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
      pendingAccessRequest = AccessRequest(
        uid: uid,
        email: email.trim().toLowerCase(),
        fullName: fullName.trim(),
        userType: userType.value,
        requestedOrgType: requestedOrgType,
        requestedOrgId: matchedOrgId ?? '',
        requestedOrgName: requestedCompanyName.trim(),
        requestedRole: requestedRole ?? '',
        requestedProjectName: requestedProjectName ?? '',
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
      profileWritten = true;
      await accessRepo.createPendingRequest(pendingAccessRequest);
      accessRequestWritten = true;
      await waitForProfileDocument(uid);
      if (kDebugMode) debugPrint('[Auth] profile saved users/$uid');
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] register error: $e');
      if (createdUser == null) {
        throw Exception(AuthErrorMessages.from(e));
      }
      if (!profileWritten) {
        // Nothing was persisted to Firestore yet, so the Auth account is
        // safe to roll back — this frees the email for a clean retry.
        // (users/{uid} and accessRequests/{uid} cannot be deleted by rule
        // once written, so once either exists we must heal forward instead.)
        try {
          await createdUser.delete();
        } catch (deleteError) {
          if (kDebugMode) {
            debugPrint('[Auth] rollback auth user failed: $deleteError');
          }
        }
      } else if (!accessRequestWritten && pendingAccessRequest != null) {
        // The profile document landed but the access request didn't — an
        // admin can never see this user to approve them. Repair it now
        // rather than deleting the (now undeletable) Auth account and
        // stranding the profile forever.
        try {
          await accessRepo.createPendingRequest(pendingAccessRequest);
        } catch (repairError) {
          if (kDebugMode) {
            debugPrint('[Auth] access request repair failed: $repairError');
          }
        }
      }
      throw Exception(AuthErrorMessages.from(e));
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
  ///
  /// Mirrors [register]: also raises the pending [AccessRequest] so the
  /// repaired profile is visible to an org admin for approval, the same way
  /// a normal registration is. Without it the user is stuck in
  /// `pendingApproval` with nothing for anyone to approve.
  Future<AppUser> completeMissingProfile({
    required UserType userType,
    required String fullName,
    required String phone,
    required String city,
    String? notes,
    required String requestedCompanyName,
    String? requestedRole,
    String? requestedProjectName,
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
      final profile = AppUser.fromMap(existing.id, existing.data()!);
      await _ensurePendingAccessRequest(profile);
      return profile;
    }

    final email = firebaseUser.email?.trim() ?? '';
    if (email.isEmpty) {
      throw Exception('חסר אימייל בחשבון ההתחברות');
    }

    final requestedOrgType =
        userType.isSupplier ? OrganizationType.supplier : OrganizationType.contractor;
    final accessRepo = AccessRequestRepository(firestore: _firestoreDb);
    final matchedOrgId = await accessRepo.resolveOrgIdByName(
      companyName: requestedCompanyName,
      type: requestedOrgType,
    );

    final appUser = AppUser(
      id: firebaseUser.uid,
      fullName: fullName.trim(),
      email: email,
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

    try {
      await ref.set(
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
          uid: firebaseUser.uid,
          email: email.toLowerCase(),
          fullName: fullName.trim(),
          userType: userType.value,
          requestedOrgType: requestedOrgType,
          requestedOrgId: matchedOrgId ?? '',
          requestedOrgName: requestedCompanyName.trim(),
          requestedRole: requestedRole ?? '',
          requestedProjectName: requestedProjectName ?? '',
        ),
      );
      await waitForProfileDocument(firebaseUser.uid);
      return appUser;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] completeMissingProfile error: $e');
      throw Exception(AuthErrorMessages.from(e));
    }
  }

  /// Backfills a pending [AccessRequest] for a profile that already exists
  /// but (e.g. from an earlier interrupted registration) never got one.
  Future<void> _ensurePendingAccessRequest(AppUser profile) async {
    if (profile.accountStatus != AccountStatus.pendingApproval) return;
    final accessRepo = AccessRequestRepository(firestore: _firestoreDb);
    final existingRequest = await _firestoreDb
        .collection(AppConstants.accessRequestsCollection)
        .doc(profile.id)
        .get();
    if (existingRequest.exists) return;

    final requestedOrgType = OrganizationType.fromValue(profile.requestedOrgType) ??
        (profile.userType.isSupplier
            ? OrganizationType.supplier
            : OrganizationType.contractor);
    try {
      await accessRepo.createPendingRequest(
        AccessRequest(
          uid: profile.id,
          email: profile.email.trim().toLowerCase(),
          fullName: profile.fullName,
          userType: profile.userType.value,
          requestedOrgType: requestedOrgType,
          requestedOrgId: profile.requestedOrgId ?? '',
          requestedOrgName: profile.requestedOrgName ?? '',
          requestedRole: profile.requestedRole ?? '',
          requestedProjectName: profile.requestedProjectName ?? '',
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] access request backfill failed: $e');
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

  /// Sends a reset email if the address has an account. Deliberately does
  /// not surface "user-not-found" as an error, so the UI can't be used to
  /// enumerate which emails are registered.
  Future<void> resetPassword(String email) async {
    if (AppMode.isDemoMode) {
      throw Exception('במצב הדגמה איפוס סיסמה אינו זמין');
    }

    try {
      if (kDebugMode) debugPrint('[Auth] resetPassword: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      if (kDebugMode) debugPrint('[Auth] resetPassword error: $e');
      throw Exception(AuthErrorMessages.from(e));
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] resetPassword error: $e');
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
