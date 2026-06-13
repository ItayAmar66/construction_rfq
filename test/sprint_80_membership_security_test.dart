import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/membership_role_update_errors.dart';
import 'package:construction_rfq/widgets/permissions/role_change_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.demoMemberships.clear();
  });

  group('MembershipRoleUpdateErrors', () {
    test('permission denied maps to Hebrew', () {
      expect(
        MembershipRoleUpdateErrors.userMessage(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        ),
        MembershipRoleUpdateErrors.permissionDenied,
      );
    });

    test('known client messages pass through', () {
      expect(
        MembershipRoleUpdateErrors.userMessage(
          Exception(MembershipRoleUpdateErrors.selfChangeBlocked),
        ),
        MembershipRoleUpdateErrors.selfChangeBlocked,
      );
    });

    test('unknown errors use generic message', () {
      expect(
        MembershipRoleUpdateErrors.userMessage(Exception('internal')),
        MembershipRoleUpdateErrors.genericFailure,
      );
    });
  });

  group('OrganizationRepository last-owner guard', () {
    final repo = OrganizationRepository();

    setUp(() {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'owner-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorCompanyOwner],
      ));
    });

    test('cannot demote last contractor owner', () {
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
            (e) =>
                e.toString().contains(
                      MembershipRoleUpdateErrors.lastOwnerBlocked,
                    ),
          ),
        ),
      );
    });
  });

  group('OrganizationRepository self-change guard', () {
    test('self-change blocked before write', () {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'eng-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      ));
      expect(
        () => OrganizationRepository().updateMemberRole(
          orgId: 'org-1',
          memberUid: 'eng-1',
          newRole: EnterpriseRole.procurementManager,
          actorUid: 'eng-1',
          orgType: OrganizationType.contractor,
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains(
                      MembershipRoleUpdateErrors.selfChangeBlocked,
                    ),
          ),
        ),
      );
    });

    test('invalid supplier role blocked for contractor org', () {
      MockStore.instance.setDemoMembership(Membership(
        uid: 'owner-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.contractorCompanyOwner],
      ));
      MockStore.instance.setDemoMembership(Membership(
        uid: 'eng-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      ));
      expect(
        () => OrganizationRepository().updateMemberRole(
          orgId: 'org-1',
          memberUid: 'eng-1',
          newRole: EnterpriseRole.supplierOps,
          actorUid: 'owner-1',
          orgType: OrganizationType.contractor,
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains(MembershipRoleUpdateErrors.wrongOrgRole),
          ),
        ),
      );
    });
  });

  testWidgets('role change dialog shows permission denied message',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => RoleChangeDialog.show(
                context: ctx,
                membership: Membership(
                  uid: 'u1',
                  orgId: 'org-1',
                  orgType: OrganizationType.contractor,
                  roles: const [EnterpriseRole.engineer],
                ),
                displayName: 'Test User',
                orgType: OrganizationType.contractor,
                allowedRoles: const [EnterpriseRole.engineer],
                onSave: (_) async {
                  throw FirebaseException(
                    plugin: 'firestore',
                    code: 'permission-denied',
                  );
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('שמור שינוי'));
    await tester.pumpAndSettle();
    expect(
      find.text(MembershipRoleUpdateErrors.permissionDenied),
      findsOneWidget,
    );
  });
}
