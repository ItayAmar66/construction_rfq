import 'dart:io';

import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/utils/team_permissions_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = File('${Directory.current.path}/firestore.rules').readAsStringSync();

  group('Team permissions rules', () {
    test('platform admin can update membership roles status and projectIds', () {
      expect(rules, contains('function membershipAdminUpdateAllowed(orgId, memberUid)'));
      expect(rules, contains("'projectIds'"));
      expect(rules, contains("'roles'"));
      expect(rules, contains("'status'"));
    });

    test('org owner can manage memberships in own org only', () {
      expect(rules, contains('function canManageOrgMemberships(orgId)'));
      expect(rules, contains('isContractorCompanyOwner(orgId)'));
      expect(rules, contains('isSupplierOwner(orgId)'));
    });

    test('platformAdmin cannot be assigned via membership roles validation', () {
      expect(rules, contains("role != 'platformAdmin'"));
      expect(rules, contains("!('platformAdmin' in request.resource.data.roles)"));
    });

    test('project managers can manage project assignments', () {
      expect(rules, contains('function canManageProjectAssignments(projectId)'));
      expect(rules, contains('function isProjectManagerFor(projectId)'));
    });

    test('admin user management supports disabled and rejected statuses', () {
      expect(rules, contains("'disabled'"));
      expect(rules, contains("'rejected'"));
    });
  });

  group('Team permissions policy', () {
    test('regular engineer cannot edit permissions', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.engineer],
          orgType: OrganizationType.contractor,
          actorUid: 'eng',
          targetUid: 'other',
        ),
        isFalse,
      );
    });

    test('contractor owner cannot grant platformAdmin through assignable roles', () {
      final roles = TeamPermissionsPolicy.assignableRoles(
        orgType: OrganizationType.contractor,
        actorRoles: const [EnterpriseRole.contractorCompanyOwner],
        isPlatformAdmin: false,
      );
      expect(roles, isNot(contains(EnterpriseRole.platformAdmin)));
    });

    test('supplier owner cannot manage contractor org', () {
      expect(
        TeamPermissionsPolicy.canEditMemberPermissions(
          isPlatformAdmin: false,
          actorRoles: const [EnterpriseRole.supplierOwner],
          orgType: OrganizationType.contractor,
          actorUid: 'supplier-owner',
          targetUid: 'user',
        ),
        isFalse,
      );
    });
  });
}
