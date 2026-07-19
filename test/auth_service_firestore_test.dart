import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/auth_service.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

/// Real (non-demo) AuthService flows against a fake Firestore + fake Auth —
/// this project's tests otherwise all go through AppMode.demoMode/MockStore,
/// which never exercised these code paths at all.
void main() {
  group('register', () {
    test('creates both the user profile and the pending access request', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, firestore: firestore);

      await service.register(
        fullName: 'קבלן בדיקה',
        phone: '0501111111',
        email: 'contractor@test.com',
        password: 'Password1!',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        requestedCompanyName: 'חברת קבלנות בדיקה',
      );

      final uid = auth.currentUser!.uid;
      final userDoc =
          await firestore.collection(AppConstants.usersCollection).doc(uid).get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()!['accountStatus'], AccountStatus.pendingApproval.value);

      final accessRequestDoc = await firestore
          .collection(AppConstants.accessRequestsCollection)
          .doc(uid)
          .get();
      expect(accessRequestDoc.exists, isTrue);
      expect(accessRequestDoc.data()!['status'], 'pending');
      expect(accessRequestDoc.data()!['requestedOrgName'], 'חברת קבלנות בדיקה');
    });

    test('a failure before any Firestore write leaves no orphaned auth account',
        () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, firestore: firestore);

      whenCalling(Invocation.method(
        #createUserWithEmailAndPassword,
        null,
        {#email: 'blocked@test.com', #password: anything},
      )).on(auth).thenThrow(
            FirebaseAuthException(code: 'network-request-failed'),
          );

      await expectLater(
        service.register(
          fullName: 'נחסם',
          phone: '0501111111',
          email: 'blocked@test.com',
          password: 'Password1!',
          userType: UserType.commercialCustomer,
          city: 'תל אביב',
          requestedCompanyName: 'חברה',
        ),
        throwsA(isA<Exception>()),
      );

      expect(auth.currentUser, isNull,
          reason: 'a failure before any write must not leave a signed-in orphan');
      final users = await firestore.collection(AppConstants.usersCollection).get();
      expect(users.docs, isEmpty);
      final accessRequests =
          await firestore.collection(AppConstants.accessRequestsCollection).get();
      expect(accessRequests.docs, isEmpty);
    });

    // Note: the "profile written but access request missing" self-heal
    // branch (register()'s catch block re-attempting createPendingRequest,
    // and NOT deleting the now-undeletable-by-rule Auth account) is
    // exercised indirectly via the completeMissingProfile/backfill tests
    // below, which cover the same underlying repair path through a more
    // controllable entry point — MockFirebaseAuth's generated uid can't be
    // predicted ahead of time to target a mid-flight Firestore write for
    // register() itself.
  });

  group('completeMissingProfile', () {
    test('creates the profile and a matching pending access request', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'repair-uid', email: 'repair@test.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      final profile = await service.completeMissingProfile(
        userType: UserType.commercialSupplier,
        fullName: 'ספק לתיקון',
        phone: '0503333333',
        city: 'באר שבע',
        requestedCompanyName: 'ספק בדיקה בע"מ',
      );

      expect(profile.id, 'repair-uid');

      final accessRequestDoc = await firestore
          .collection(AppConstants.accessRequestsCollection)
          .doc('repair-uid')
          .get();
      expect(accessRequestDoc.exists, isTrue,
          reason:
              'profile repair must raise an access request, same as normal registration');
      expect(accessRequestDoc.data()!['requestedOrgName'], 'ספק בדיקה בע"מ');
      expect(accessRequestDoc.data()!['userType'], UserType.commercialSupplier.value);
    });

    test('backfills a missing access request for an already-existing pending profile',
        () async {
      // Simulates the aftermath of an interrupted registration where the
      // profile document landed but the access request never did.
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'orphan-uid', email: 'orphan@test.com'),
      );
      await firestore.collection(AppConstants.usersCollection).doc('orphan-uid').set({
        'uid': 'orphan-uid',
        'name': 'משתמש יתום',
        'fullName': 'משתמש יתום',
        'email': 'orphan@test.com',
        'phone': '0504444444',
        'userType': UserType.commercialCustomer.value,
        'city': 'אשדוד',
        'accountStatus': AccountStatus.pendingApproval.value,
        'requestedOrgName': 'חברה יתומה',
        'requestedOrgType': 'contractor',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final service = AuthService(auth: auth, firestore: firestore);

      final profile = await service.completeMissingProfile(
        userType: UserType.commercialCustomer,
        fullName: 'משתמש יתום',
        phone: '0504444444',
        city: 'אשדוד',
        requestedCompanyName: 'חברה יתומה',
      );

      expect(profile.id, 'orphan-uid');
      final accessRequestDoc = await firestore
          .collection(AppConstants.accessRequestsCollection)
          .doc('orphan-uid')
          .get();
      expect(accessRequestDoc.exists, isTrue);
      expect(accessRequestDoc.data()!['requestedOrgName'], 'חברה יתומה');
    });

    test('does not duplicate an access request that already exists', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'has-request-uid', email: 'has-request@test.com'),
      );
      await firestore
          .collection(AppConstants.usersCollection)
          .doc('has-request-uid')
          .set({
        'uid': 'has-request-uid',
        'name': 'יש בקשה',
        'email': 'has-request@test.com',
        'phone': '0505555555',
        'userType': UserType.commercialCustomer.value,
        'city': 'נתניה',
        'accountStatus': AccountStatus.pendingApproval.value,
      });
      await firestore
          .collection(AppConstants.accessRequestsCollection)
          .doc('has-request-uid')
          .set({
        'uid': 'has-request-uid',
        'email': 'has-request@test.com',
        'fullName': 'יש בקשה',
        'userType': UserType.commercialCustomer.value,
        'requestedOrgType': 'contractor',
        'status': 'pending',
      });

      final service = AuthService(auth: auth, firestore: firestore);
      await service.completeMissingProfile(
        userType: UserType.commercialCustomer,
        fullName: 'יש בקשה',
        phone: '0505555555',
        city: 'נתניה',
        requestedCompanyName: 'לא רלוונטי',
      );

      final snap = await firestore
          .collection(AppConstants.accessRequestsCollection)
          .where('uid', isEqualTo: 'has-request-uid')
          .get();
      expect(snap.docs.length, 1);
    });
  });
}
