import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/platform_access_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformAccessGateResolver', () {
    test('no membership active user -> no permission', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.active,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.noPermission,
      );
    });

    test('pending approval user -> pending approval gate', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.pendingApproval,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.pendingApproval,
      );
    });

    test('active membership -> granted', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: true,
          accountStatus: AccountStatus.active,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.granted,
      );
    });

    test('unsettled memberships stay loading', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: false,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.active,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.loading,
      );
    });

    test('unauthenticated after bootstrap resolves to no permission', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: false,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.active,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.loading,
      );
    });

    test('permission-denied membership load -> membership error', () {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: AccountStatus.active,
          membershipLoadError: true,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.membershipError,
      );
    });
  });

  group('EffectivePermissions QA users', () {
    test('active enterprise membership grants platform access', () {
      final user = AppUser(
        id: 'proc-1',
        fullName: 'רכש QA',
        email: 'qa.contractor.big.procurement@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      );
      const memberships = [
        Membership(
          uid: 'proc-1',
          orgId: 'org-big',
          orgType: OrganizationType.contractor,
          roles: [EnterpriseRole.procurementManager],
          status: 'active',
        ),
      ];

      expect(
        EffectivePermissions.hasPlatformAccess(
          user: user,
          memberships: memberships,
        ),
        isTrue,
      );
    });
  });

  group('membership stream bootstrap', () {
    test('demo memberships stream emits empty list immediately', () async {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      addTearDown(() => AppMode.isDemoMode = false);

      final first = await MockStore.instance
          .watchMembershipsForUser('no-membership-user')
          .first
          .timeout(const Duration(seconds: 2));
      expect(first, isEmpty);
    });
  });
}
