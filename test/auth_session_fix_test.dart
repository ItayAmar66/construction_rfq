// Tests for authSessionFromProfileStream (lib/services/auth_service.dart),
// covering the fix for the stale-session bug flagged by the Final Release
// Review Board: watchAuthSession() used to swallow permission-denied
// Firestore errors, so a revoked profile never reached the router.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException _permissionDenied() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );

Future<Map<String, dynamic>> _claims({bool emailVerified = true}) async =>
    {'email_verified': emailVerified};

void main() {
  group('authSessionFromProfileStream', () {
    test('disabled account: permission-denied emits AuthSession.empty', () async {
      final controller = StreamController<ProfileDocEvent>();
      final sessions = authSessionFromProfileStream(
        uid: 'disabled-user',
        profileSnapshots: controller.stream,
        loadClaims: _claims,
      );

      final emitted = <AuthSession>[];
      final errors = <Object>[];
      final sub = sessions.listen(emitted.add, onError: errors.add);

      controller.addError(_permissionDenied());
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [AuthSession.empty]);
      expect(errors, isEmpty);
      expect(emitted.single.isAuthenticated, isFalse);

      await sub.cancel();
      await controller.close();
    });

    test('revoked membership: permission-denied after prior valid session '
        'still resolves to empty (no stale session)', () async {
      final controller = StreamController<ProfileDocEvent>();
      final sessions = authSessionFromProfileStream(
        uid: 'revoked-user',
        profileSnapshots: controller.stream,
        loadClaims: _claims,
      );

      final emitted = <AuthSession>[];
      final sub = sessions.listen(emitted.add);

      controller.add(ProfileDocEvent(
        exists: true,
        data: {
          'name': 'Revoked User',
          'fullName': 'Revoked User',
          'email': 'r@test.com',
          'phone': '050',
          'userType': 'commercialCustomer',
          'city': 'תל אביב',
        },
        id: 'revoked-user',
      ));
      await Future<void>.delayed(Duration.zero);
      expect(emitted, hasLength(1));
      expect(emitted.last.isAuthenticated, isTrue);
      expect(emitted.last.hasProfile, isTrue);

      controller.addError(_permissionDenied());
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(2));
      expect(emitted.last, AuthSession.empty);
      expect(emitted.last.isAuthenticated, isFalse);

      await sub.cancel();
      await controller.close();
    });

    test('deleted profile (doc missing): existing profile-missing flow '
        'is preserved, not treated as permission-denied', () async {
      final controller = StreamController<ProfileDocEvent>();
      final sessions = authSessionFromProfileStream(
        uid: 'gone-user',
        profileSnapshots: controller.stream,
        loadClaims: _claims,
      );

      final emitted = <AuthSession>[];
      final sub = sessions.listen(emitted.add);

      controller.add(ProfileDocEvent(exists: false, id: 'gone-user'));
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      expect(emitted.single.uid, 'gone-user');
      expect(emitted.single.profileMissing, isTrue);
      expect(emitted.single.hasProfile, isFalse);

      await sub.cancel();
      await controller.close();
    });

    test('permission denied: sink closes so no infinite reconnect loop',
        () async {
      final controller = StreamController<ProfileDocEvent>();
      final sessions = authSessionFromProfileStream(
        uid: 'closed-user',
        profileSnapshots: controller.stream,
        loadClaims: _claims,
      );

      final emitted = <AuthSession>[];
      var didClose = false;
      final sub = sessions.listen(emitted.add, onDone: () => didClose = true);

      controller.addError(_permissionDenied());
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [AuthSession.empty]);
      expect(didClose, isTrue);

      await sub.cancel();
      await controller.close();
    });

    test('non-permission Firestore errors still propagate (not swallowed)',
        () async {
      final controller = StreamController<ProfileDocEvent>();
      final sessions = authSessionFromProfileStream(
        uid: 'other-error-user',
        profileSnapshots: controller.stream,
        loadClaims: _claims,
      );

      final errors = <Object>[];
      final sub = sessions.listen((_) {}, onError: errors.add);

      controller.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));

      await sub.cancel();
      await controller.close();
    });

    test('reconnect: a fresh subscription after permission-denied gets a '
        'clean session once access is restored', () async {
      // First subscription: gets permission-denied, ends in AuthSession.empty.
      final firstController = StreamController<ProfileDocEvent>();
      final firstEmitted = <AuthSession>[];
      final firstSub = authSessionFromProfileStream(
        uid: 'reconnect-user',
        profileSnapshots: firstController.stream,
        loadClaims: _claims,
      ).listen(firstEmitted.add);

      firstController.addError(_permissionDenied());
      await Future<void>.delayed(Duration.zero);
      expect(firstEmitted, [AuthSession.empty]);
      await firstSub.cancel();
      await firstController.close();

      // Simulates the outer authStateChanges().asyncExpand(...) establishing
      // a brand-new profile stream (e.g. after re-login or rule change) —
      // this must yield a normal, live session again.
      final secondController = StreamController<ProfileDocEvent>();
      final secondEmitted = <AuthSession>[];
      final secondSub = authSessionFromProfileStream(
        uid: 'reconnect-user',
        profileSnapshots: secondController.stream,
        loadClaims: _claims,
      ).listen(secondEmitted.add);

      secondController.add(ProfileDocEvent(
        exists: true,
        data: {
          'name': 'Reconnected User',
          'fullName': 'Reconnected User',
          'email': 'reconnect@test.com',
          'phone': '050',
          'userType': 'commercialCustomer',
          'city': 'תל אביב',
        },
        id: 'reconnect-user',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(secondEmitted, hasLength(1));
      expect(secondEmitted.single.isAuthenticated, isTrue);
      expect(secondEmitted.single.hasProfile, isTrue);

      await secondSub.cancel();
      await secondController.close();
    });

    test('logout then login again: two independent session streams do not '
        'leak state between them', () async {
      final loggedOutController = StreamController<ProfileDocEvent>();
      final loggedOutEmitted = <AuthSession>[];
      final loggedOutSub = authSessionFromProfileStream(
        uid: 'user-a',
        profileSnapshots: loggedOutController.stream,
        loadClaims: _claims,
      ).listen(loggedOutEmitted.add);

      loggedOutController.addError(_permissionDenied());
      await Future<void>.delayed(Duration.zero);
      expect(loggedOutEmitted, [AuthSession.empty]);
      await loggedOutSub.cancel();
      await loggedOutController.close();

      // "logout": outer authStateChanges emits null -> AuthSession.empty
      // directly (no profile stream at all). Modeled here as a stream with
      // no profile subscription, matching watchAuthSession's early return.

      // "login again" as a different user establishes a brand-new stream.
      final newUserController = StreamController<ProfileDocEvent>();
      final newUserEmitted = <AuthSession>[];
      final newUserSub = authSessionFromProfileStream(
        uid: 'user-b',
        profileSnapshots: newUserController.stream,
        loadClaims: _claims,
      ).listen(newUserEmitted.add);

      newUserController.add(ProfileDocEvent(
        exists: true,
        data: {
          'name': 'User B',
          'fullName': 'User B',
          'email': 'b@test.com',
          'phone': '050',
          'userType': 'commercialCustomer',
          'city': 'חיפה',
        },
        id: 'user-b',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(newUserEmitted, hasLength(1));
      expect(newUserEmitted.single.uid, 'user-b');
      expect(newUserEmitted.single.isAuthenticated, isTrue);

      await newUserSub.cancel();
      await newUserController.close();
    });
  });
}
