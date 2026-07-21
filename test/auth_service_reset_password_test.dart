import 'package:construction_rfq/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  group('AuthService.resetPassword', () {
    test('sends a reset email for a registered address', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, firestore: FakeFirebaseFirestore());

      await service.resetPassword('customer@test.com');
      // No exception thrown — MockFirebaseAuth's default behavior succeeds.
    });

    test('does not surface user-not-found (avoids email enumeration)',
        () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, firestore: FakeFirebaseFirestore());

      whenCalling(Invocation.method(
        #sendPasswordResetEmail,
        null,
        {#email: 'unknown@test.com', #actionCodeSettings: null},
      )).on(auth).thenThrow(
            FirebaseAuthException(code: 'user-not-found'),
          );

      await service.resetPassword('unknown@test.com');
      // Should complete without throwing.
    });

    test('surfaces other Firebase Auth errors', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, firestore: FakeFirebaseFirestore());

      whenCalling(Invocation.method(
        #sendPasswordResetEmail,
        null,
        {#email: 'bad@test.com', #actionCodeSettings: null},
      )).on(auth).thenThrow(
            FirebaseAuthException(code: 'invalid-email'),
          );

      await expectLater(
        () => service.resetPassword('bad@test.com'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
