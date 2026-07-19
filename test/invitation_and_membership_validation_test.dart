import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/repositories/invitation_repository.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/constants.dart';
import 'package:construction_rfq/utils/membership_role_update_errors.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for Phase 4 #4 (project access synchronization), #5
/// (invitation validation) and #6 (membership validation).
void main() {
  group('InvitationRepository.acceptInvitation project-assignment sync (#4)', () {
    setUp(() => AppMode.isDemoMode = false);

    Future<FakeFirebaseFirestore> seeded({required String inviteStatus}) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(AppConstants.invitationsCollection).doc('invite-1').set({
        'orgId': 'org-1',
        'orgType': 'contractor',
        'email': 'invitee@test.com',
        'role': 'engineer',
        'status': inviteStatus,
        'deliveryStatus': 'pending',
        'invitedByUid': 'inviter-1',
        'projectIds': ['proj-1'],
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 5))),
      });
      await firestore.collection(AppConstants.usersCollection).doc('invitee-1').set({
        'uid': 'invitee-1',
        'name': 'מוזמן',
        'email': 'invitee@test.com',
        'phone': '050',
        'userType': 'commercialCustomer',
        'city': 'תל אביב',
        'accountStatus': 'pendingApproval',
      });
      return firestore;
    }

    test('materializes the project assignment doc, not just the membership cache',
        () async {
      final firestore = await seeded(inviteStatus: 'pending');
      final repo = InvitationRepository(firestore: firestore);

      final membership = await repo.acceptInvitation(
        inviteId: 'invite-1',
        uid: 'invitee-1',
        email: 'invitee@test.com',
      );

      expect(membership.projectIds, contains('proj-1'));

      final assignmentDoc = await firestore
          .collection(AppConstants.projectsCollection)
          .doc('proj-1')
          .collection('assignments')
          .doc('invitee-1')
          .get();
      expect(assignmentDoc.exists, isTrue,
          reason: 'the authoritative assignment doc must exist, not just the '
              'membership.projectIds cache');
      expect(assignmentDoc.data()!['sourceInvitationId'], 'invite-1');

      final inviteDoc = await firestore
          .collection(AppConstants.invitationsCollection)
          .doc('invite-1')
          .get();
      expect(inviteDoc.data()!['status'], 'accepted');
    });

    test('invitation is marked accepted before the project-assignment writes run',
        () {
      // Regression guard for the exact ordering bug: firestore.rules'
      // projectAssignmentFromInvitationAllowed requires the invitation to
      // already read back status=='accepted' at the moment the assignment
      // doc is created. fake_cloud_firestore doesn't enforce rules, so a
      // wrong-order regression wouldn't fail the test above — assert the
      // ordering directly in source.
      final source = File(
        '${Directory.current.path}/lib/repositories/invitation_repository.dart',
      ).readAsStringSync();
      final acceptStart = source.indexOf('Future<Membership> acceptInvitation(');
      final acceptEnd = source.indexOf('\n  Future<void> _updateDeliveryStatus');
      final body = source.substring(acceptStart, acceptEnd);

      final inviteAcceptedUpdateIndex = body.indexOf("'status': 'accepted'");
      final assignmentLoopIndex = body.indexOf('for (final projectId in invite.projectIds)');

      expect(inviteAcceptedUpdateIndex, greaterThan(-1));
      expect(assignmentLoopIndex, greaterThan(-1));
      expect(
        inviteAcceptedUpdateIndex,
        lessThan(assignmentLoopIndex),
        reason: 'invite must be marked accepted before the project '
            'assignment docs are created, or the rule that authorizes '
            'those writes always rejects them',
      );
    });
  });

  group('InvitationRepository self-invite-to-owner guard (#5)', () {
    test('cannot invite your own email as contractorOwner', () async {
      await expectLater(
        InvitationRepository().createInvitation(
          orgId: 'org-1',
          orgType: OrganizationType.contractor,
          email: 'me@test.com',
          role: EnterpriseRole.contractorOwner,
          invitedByUid: 'me',
          invitedByEmail: 'me@test.com',
          canManage: true,
        ),
        throwsA(
          predicate((e) => e.toString().contains('לא ניתן להזמין את עצמך')),
        ),
      );
    });

    test('can invite a different email as contractorOwner', () async {
      AppMode.enableDemoMode();
      addTearDown(() => AppMode.isDemoMode = false);
      MockStore.instance.init();
      await expectLater(
        InvitationRepository().createInvitation(
          orgId: 'org-1',
          orgType: OrganizationType.contractor,
          email: 'someone-else@test.com',
          role: EnterpriseRole.contractorOwner,
          invitedByUid: 'me',
          invitedByEmail: 'me@test.com',
          canManage: true,
        ),
        completes,
      );
    });

    test('can invite yourself for a non-owner role', () async {
      AppMode.enableDemoMode();
      addTearDown(() => AppMode.isDemoMode = false);
      MockStore.instance.init();
      await expectLater(
        InvitationRepository().createInvitation(
          orgId: 'org-1',
          orgType: OrganizationType.contractor,
          email: 'me@test.com',
          role: EnterpriseRole.engineer,
          invitedByUid: 'me',
          invitedByEmail: 'me@test.com',
          canManage: true,
        ),
        completes,
      );
    });
  });

  group('OrganizationRepository last-owner guard matches org.ownerUid (#6)', () {
    setUp(() => AppMode.isDemoMode = false);

    test('blocks demoting the org\'s recorded owner even with a co-owner present',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(AppConstants.organizationsCollection).doc('org-1').set({
        'type': 'contractor',
        'name': 'חברה',
        'ownerUid': 'real-owner',
        'status': 'active',
      });
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org-1')
          .collection(AppConstants.membershipsSubcollection)
          .doc('real-owner')
          .set({
        'uid': 'real-owner',
        'orgId': 'org-1',
        'orgType': 'contractor',
        'roles': ['contractorOwner'],
        'status': 'active',
      });
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org-1')
          .collection(AppConstants.membershipsSubcollection)
          .doc('co-owner')
          .set({
        'uid': 'co-owner',
        'orgId': 'org-1',
        'orgType': 'contractor',
        'roles': ['contractorOwner'],
        'status': 'active',
      });

      final repo = OrganizationRepository(firestore: firestore);
      await expectLater(
        repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'real-owner',
          newRole: EnterpriseRole.engineer,
          actorUid: 'some-admin',
          orgType: OrganizationType.contractor,
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains(MembershipRoleUpdateErrors.lastOwnerBlocked),
          ),
        ),
      );
    });

    test('allows demoting a non-designated co-owner (server rule permits it)',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(AppConstants.organizationsCollection).doc('org-1').set({
        'type': 'contractor',
        'name': 'חברה',
        'ownerUid': 'real-owner',
        'status': 'active',
      });
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org-1')
          .collection(AppConstants.membershipsSubcollection)
          .doc('real-owner')
          .set({
        'uid': 'real-owner',
        'orgId': 'org-1',
        'orgType': 'contractor',
        'roles': ['contractorOwner'],
        'status': 'active',
      });
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org-1')
          .collection(AppConstants.membershipsSubcollection)
          .doc('co-owner')
          .set({
        'uid': 'co-owner',
        'orgId': 'org-1',
        'orgType': 'contractor',
        'roles': ['contractorOwner'],
        'status': 'active',
      });

      final repo = OrganizationRepository(firestore: firestore);
      // A count-based "last owner" heuristic would have blocked this too
      // (ownerCount would drop from 2 to 1) — the server rule only cares
      // about organizations/{orgId}.ownerUid, so demoting the OTHER owner
      // must be allowed.
      await expectLater(
        repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'co-owner',
          newRole: EnterpriseRole.engineer,
          actorUid: 'some-admin',
          orgType: OrganizationType.contractor,
        ),
        completes,
      );
    });

    test('demo mode (no organizations collection) falls back to the count heuristic',
        () {
      AppMode.enableDemoMode();
      addTearDown(() => AppMode.isDemoMode = false);
      MockStore.instance.init();
      MockStore.instance.demoMemberships.clear();
      MockStore.instance.setDemoMembership(Membership(
        uid: 'owner-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorOwner],
      ));
      final repo = OrganizationRepository();
      expect(
        () => repo.updateMemberRole(
          orgId: 'org-1',
          memberUid: 'owner-1',
          newRole: EnterpriseRole.engineer,
          actorUid: 'other-admin',
          orgType: OrganizationType.contractor,
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains(MembershipRoleUpdateErrors.lastOwnerBlocked),
          ),
        ),
      );
    });
  });
}
