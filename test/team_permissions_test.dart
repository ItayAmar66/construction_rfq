import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/utils/team_permissions_policy.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/widgets/permissions/team_permissions_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeamPermissionsPolicy', () {
    test('platform admin can edit any member', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: true,
          actorRoles: const [],
          orgType: OrganizationType.contractor,
          actorUid: 'admin',
          targetUid: 'user',
        ),
        isTrue,
      );
    });

    test('contractor owner can edit own org members', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.contractorCompanyOwner],
          orgType: OrganizationType.contractor,
          actorUid: 'owner',
          targetUid: 'user',
        ),
        isTrue,
      );
    });

    test('contractor owner cannot edit self', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.contractorCompanyOwner],
          orgType: OrganizationType.contractor,
          actorUid: 'owner',
          targetUid: 'owner',
        ),
        isFalse,
      );
    });

    test('procurement manager cannot edit roles', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.procurementManager],
          orgType: OrganizationType.contractor,
          actorUid: 'pm-proc',
          targetUid: 'user',
        ),
        isFalse,
      );
      expect(
        TeamPermissionsPolicy.readOnlyMessage(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.procurementManager],
          orgType: OrganizationType.contractor,
        ),
        'רק מנהל חברה יכול לשנות הרשאות',
      );
    });

    test('project manager can edit project access only', () {
      expect(
        TeamPermissionsPolicy.canEditProjectAccess(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.projectManager],
          orgType: OrganizationType.contractor,
        ),
        isTrue,
      );
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.projectManager],
          orgType: OrganizationType.contractor,
          actorUid: 'pm',
          targetUid: 'user',
        ),
        isFalse,
      );
    });

    test('supplier owner can edit supplier team', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.supplierOwner],
          orgType: OrganizationType.supplier,
          actorUid: 'owner',
          targetUid: 'user',
        ),
        isTrue,
      );
    });

    test('platform admin assignable roles exclude platformAdmin', () {
      final roles = TeamPermissionsPolicy.assignableRoles(
        orgType: OrganizationType.contractor,
        actorRoles: const [],
        isPlatformAdmin: true,
      );
      expect(roles, isNot(contains(EnterpriseRole.platformAdmin)));
      expect(roles, contains(EnterpriseRole.engineer));
    });

    test('contractor owner assignable roles exclude platformAdmin', () {
      final roles = TeamPermissionsPolicy.assignableRoles(
        orgType: OrganizationType.contractor,
        actorRoles: const [EnterpriseRole.contractorCompanyOwner],
        isPlatformAdmin: false,
      );
      expect(roles, isNot(contains(EnterpriseRole.platformAdmin)));
      expect(roles, contains(EnterpriseRole.procurementManager));
    });
  });

  testWidgets('team section renders title', (tester) async {
    AppMode.enableDemoMode();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TeamPermissionsSection(
              orgId: 'org-1',
              orgType: OrganizationType.contractor,
              actorRoles: const [EnterpriseRole.contractorCompanyOwner],
              isPlatformAdmin: true,
              title: 'ניהול צוות והרשאות',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ניהול צוות והרשאות'), findsOneWidget);
  });
}
