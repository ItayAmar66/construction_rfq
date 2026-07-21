import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/repositories/admin_management_repository.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real (non-demo) AdminManagementRepository query paths against a fake
/// Firestore — covers the fetchAllMemberships parallelization fix (was a
/// sequential N+1 loop) and the newly added result-size limits.
void main() {
  group('AdminManagementRepository.fetchAllMemberships', () {
    test('aggregates memberships across every organization', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = AdminManagementRepository(firestore: firestore);

      final orgsCollection =
          firestore.collection(AppConstants.organizationsCollection);
      await orgsCollection.doc('org-a').set({
        'name': 'א',
        'type': 'contractor',
        'ownerUid': 'owner-a',
        'status': 'active',
      });
      await orgsCollection.doc('org-b').set({
        'name': 'ב',
        'type': 'supplier',
        'ownerUid': 'owner-b',
        'status': 'active',
      });

      await orgsCollection
          .doc('org-a')
          .collection(AppConstants.membershipsSubcollection)
          .doc('user-1')
          .set({
        'orgId': 'org-a',
        'orgType': 'contractor',
        'roles': ['owner'],
        'status': 'active',
      });
      await orgsCollection
          .doc('org-b')
          .collection(AppConstants.membershipsSubcollection)
          .doc('user-2')
          .set({
        'orgId': 'org-b',
        'orgType': 'supplier',
        'roles': ['owner'],
        'status': 'active',
      });

      final memberships = await repo.fetchAllMemberships();
      expect(memberships.map((m) => m.uid).toSet(), {'user-1', 'user-2'});
      expect(memberships.map((m) => m.orgId).toSet(), {'org-a', 'org-b'});
    });
  });

  group('AdminManagementRepository result-size limits', () {
    test('fetchOrganizations does not fail when many orgs exist', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = AdminManagementRepository(firestore: firestore);
      final orgsCollection =
          firestore.collection(AppConstants.organizationsCollection);
      for (var i = 0; i < 5; i++) {
        await orgsCollection.doc('org-$i').set({
          'name': 'org-$i',
          'type': 'contractor',
          'ownerUid': 'owner-$i',
          'status': 'active',
        });
      }

      final orgs = await repo.fetchOrganizations();
      expect(orgs, hasLength(5));
    });
  });
}
