import 'dart:io';

import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// HIGH-3 regression: TeamPermissionsService._validateGrantsAndRevokes must
/// compute the actor's own permissions via EffectiveAccess.forMembership
/// (role permissions minus the actor's own revokes) rather than a bare role
/// lookup, so an admin whose own permission was revoked cannot delegate it.
void main() {
  test(
    'a revoked-but-role-implied grantable permission is excluded from '
    "the actor's effective permissions",
    () {
      // procurementManager grants confirmDeliveryReceipt by role default —
      // exactly the shape of admin whose own permission gets stripped.
      final strippedActor = Membership(
        uid: 'actor-1',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
        revokes: const [Permission.confirmDeliveryReceipt],
      );

      final effective = EffectiveAccess.forMembership(strippedActor);

      expect(Permission.confirmDeliveryReceipt.isGrantable, isTrue);
      expect(
        effective.permissions.contains(Permission.confirmDeliveryReceipt),
        isFalse,
        reason: 'a stripped admin must not appear to hold the permission '
            'they would otherwise delegate to a teammate',
      );

      // An actor with the SAME role but no revoke still holds it — proves
      // this is the revoke closing the gap, not the role itself lacking it.
      final unstrippedActor = Membership(
        uid: 'actor-2',
        orgId: 'org-1',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
      );
      expect(
        EffectiveAccess.forMembership(unstrippedActor)
            .permissions
            .contains(Permission.confirmDeliveryReceipt),
        isTrue,
      );
    },
  );

  test(
    'TeamPermissionsService computes grant eligibility via '
    'EffectiveAccess.forMembership, not a bare role lookup',
    () {
      final source = File('lib/services/team_permissions_service.dart')
          .readAsStringSync();
      final start = source.indexOf('Future<Set<Permission>> _actorEffectivePermissions');
      expect(start, greaterThan(-1),
          reason: '_actorEffectivePermissions helper must exist');
      final end = source.indexOf('Future<void> _recordSensitiveChangeAudits', start);
      final block = source.substring(start, end);
      expect(block, contains('EffectiveAccess.forMembership'));

      final validateStart =
          source.indexOf('Future<void> _validateGrantsAndRevokes');
      final validateEnd = source.indexOf(
        'Future<Set<Permission>> _actorEffectivePermissions',
        validateStart,
      );
      final validateBlock = source.substring(validateStart, validateEnd);
      expect(validateBlock, contains('_actorEffectivePermissions('));
      expect(
        validateBlock,
        isNot(contains(
          'EnterprisePermissionService.permissionsForRoles(actorRoles)',
        )),
        reason: 'the non-platform-admin grants path must no longer use the '
            'bare role lookup directly',
      );
    },
  );
}
