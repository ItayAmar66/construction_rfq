import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/access_request.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/services/user_approval_service.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for "approval transaction idempotency": the approval
/// used to update the user/membership atomically but resolve the access
/// request as a separate, later, non-transactional call with no guard
/// against processing the same request twice.
void main() {
  setUp(() => AppMode.isDemoMode = false);

  const request = AccessRequest(
    uid: 'applicant-1',
    email: 'applicant@test.com',
    fullName: 'מבקש גישה',
    userType: 'commercialCustomer',
    requestedOrgType: OrganizationType.contractor,
    requestedOrgId: 'org-1',
    requestedOrgName: 'חברה',
  );

  Future<FakeFirebaseFirestore> seeded() async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection(AppConstants.usersCollection).doc('applicant-1').set({
      'uid': 'applicant-1',
      'name': 'מבקש גישה',
      'email': 'applicant@test.com',
      'phone': '050',
      'userType': 'commercialCustomer',
      'city': 'תל אביב',
      'accountStatus': 'pendingApproval',
    });
    await firestore
        .collection(AppConstants.accessRequestsCollection)
        .doc('applicant-1')
        .set({
      'uid': 'applicant-1',
      'email': 'applicant@test.com',
      'fullName': 'מבקש גישה',
      'userType': 'commercialCustomer',
      'requestedOrgType': 'contractor',
      'requestedOrgId': 'org-1',
      'requestedOrgName': 'חברה',
      'status': 'pending',
    });
    return firestore;
  }

  test('approves atomically: user active, membership created, request resolved',
      () async {
    final firestore = await seeded();
    final service = UserApprovalService(firestore: firestore);

    await service.approveAccessRequest(
      request: request,
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      role: EnterpriseRole.procurementManager,
      actorUid: 'admin-1',
    );

    final userDoc =
        await firestore.collection(AppConstants.usersCollection).doc('applicant-1').get();
    expect(userDoc.data()!['accountStatus'], 'active');
    expect(userDoc.data()!['orgId'], 'org-1');

    final membership = await firestore
        .collection(AppConstants.organizationsCollection)
        .doc('org-1')
        .collection(AppConstants.membershipsSubcollection)
        .doc('applicant-1')
        .get();
    expect(membership.exists, isTrue);
    expect(membership.data()!['roles'], contains('procurementManager'));

    final accessRequestDoc = await firestore
        .collection(AppConstants.accessRequestsCollection)
        .doc('applicant-1')
        .get();
    expect(accessRequestDoc.data()!['status'], 'approved');
    expect(accessRequestDoc.data()!['resolvedByUid'], 'admin-1');
  });

  test('rejects a second approval of the same already-resolved request', () async {
    final firestore = await seeded();
    final service = UserApprovalService(firestore: firestore);

    await service.approveAccessRequest(
      request: request,
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      role: EnterpriseRole.procurementManager,
      actorUid: 'admin-1',
    );

    // Simulate a second admin (or a double click) racing the same pending
    // request with a *different* role — this must not silently overwrite
    // the first approval's grant.
    await expectLater(
      service.approveAccessRequest(
        request: request,
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        role: EnterpriseRole.contractorViewer,
        actorUid: 'admin-2',
      ),
      throwsA(isA<Exception>()),
    );

    final membership = await firestore
        .collection(AppConstants.organizationsCollection)
        .doc('org-1')
        .collection(AppConstants.membershipsSubcollection)
        .doc('applicant-1')
        .get();
    expect(membership.data()!['roles'], contains('procurementManager'),
        reason: 'the first approval\'s role grant must survive untouched');
  });
}
