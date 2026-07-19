import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/admin_approval_service.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the "company manager approval creates duplicate
/// organizations" workflow bug: _approveManager used to always mint a new
/// org keyed to the approving user's own uid, ignoring any org already
/// matched by company name at registration time.
void main() {
  setUp(() => AppMode.isDemoMode = false);

  AppUser managerCandidate({
    required String id,
    required String requestedOrgName,
    String? requestedOrgId,
  }) {
    return AppUser(
      id: id,
      fullName: 'מנהל $id',
      email: '$id@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'תל אביב',
      createdAt: DateTime(2026),
      accountStatus: AccountStatus.pendingApproval,
      requestedOrgName: requestedOrgName,
      requestedOrgId: requestedOrgId,
      requestedOrgType: 'contractor',
    );
  }

  /// _approveManager updates the existing users/{uid} doc — as in the real
  /// app, it must already exist from registration.
  Future<void> seedUserDoc(FakeFirebaseFirestore firestore, AppUser user) async {
    await firestore.collection(AppConstants.usersCollection).doc(user.id).set({
      'uid': user.id,
      'name': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'userType': user.userType.value,
      'city': user.city,
      'accountStatus': AccountStatus.pendingApproval.value,
      if (user.requestedOrgId != null) 'requestedOrgId': user.requestedOrgId,
      if (user.requestedOrgName != null) 'requestedOrgName': user.requestedOrgName,
      if (user.requestedOrgType != null) 'requestedOrgType': user.requestedOrgType,
    });
  }

  test('reuses the org matched by requestedOrgId instead of creating a new one',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection(AppConstants.organizationsCollection)
        .doc('org-existing')
        .set({
      'type': 'contractor',
      'name': 'חברת קבלנות א',
      'ownerUid': 'first-owner',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final service = AdminApprovalService(firestore: firestore);
    final secondManager = managerCandidate(
      id: 'second-owner',
      requestedOrgName: 'חברת קבלנות א',
      requestedOrgId: 'org-existing',
    );
    await seedUserDoc(firestore, secondManager);

    await service.approveContractorManager(
      user: secondManager,
      actorUid: 'admin-1',
    );

    final orgs =
        await firestore.collection(AppConstants.organizationsCollection).get();
    expect(orgs.docs.length, 1,
        reason: 'must not create a second org for the same company');

    final membership = await firestore
        .collection(AppConstants.organizationsCollection)
        .doc('org-existing')
        .collection(AppConstants.membershipsSubcollection)
        .doc('second-owner')
        .get();
    expect(membership.exists, isTrue);
    expect(membership.data()!['roles'], contains('contractorOwner'));

    final userDoc = await firestore
        .collection(AppConstants.usersCollection)
        .doc('second-owner')
        .get();
    expect(userDoc.data()!['orgId'], 'org-existing');
  });

  test('falls back to matching by company name when requestedOrgId is missing',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection(AppConstants.organizationsCollection)
        .doc('org-by-name')
        .set({
      'type': 'contractor',
      'name': 'חברת קבלנות ב',
      'ownerUid': 'first-owner',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final service = AdminApprovalService(firestore: firestore);
    final secondManager = managerCandidate(
      id: 'second-owner-by-name',
      requestedOrgName: 'חברת קבלנות ב',
    );
    await seedUserDoc(firestore, secondManager);

    await service.approveContractorManager(
      user: secondManager,
      actorUid: 'admin-1',
    );

    final orgs =
        await firestore.collection(AppConstants.organizationsCollection).get();
    expect(orgs.docs.length, 1);
  });

  test('creates a new org when no existing company matches', () async {
    final firestore = FakeFirebaseFirestore();
    final service = AdminApprovalService(firestore: firestore);
    final manager = managerCandidate(
      id: 'brand-new-owner',
      requestedOrgName: 'חברה חדשה לגמרי',
    );
    await seedUserDoc(firestore, manager);

    await service.approveContractorManager(
      user: manager,
      actorUid: 'admin-1',
    );

    final orgs =
        await firestore.collection(AppConstants.organizationsCollection).get();
    expect(orgs.docs.length, 1);
    expect(orgs.docs.first.id, 'brand-new-owner');
  });
}
