import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/user_org_id_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserOrgIdResolver', () {
    test('includes uid and profile org fields', () {
      final ids = UserOrgIdResolver.candidateOrgIds(
        uid: 'owner-uid',
        profile: {
          'primaryOrgId': 'org-main',
          'contractorOrgId': 'org-contractor',
          'membershipOrgIds': ['org-extra'],
        },
      );

      expect(ids, containsAll(['owner-uid', 'org-main', 'org-contractor', 'org-extra']));
    });

    test('ignores legacy fallback ids', () {
      final ids = UserOrgIdResolver.candidateOrgIds(
        uid: 'user-1',
        profile: {'orgId': 'legacy-abc'},
      );

      expect(ids, {'user-1'});
    });
  });

  group('OrganizationRepository direct membership (demo)', () {
    final repo = OrganizationRepository();

    setUp(() {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      MockStore.instance.demoMemberships.clear();
    });

    tearDown(() {
      AppMode.isDemoMode = false;
    });

    Membership _membership({
      required String uid,
      required String orgId,
      required EnterpriseRole role,
    }) {
      return Membership(
        uid: uid,
        orgId: orgId,
        orgType: OrganizationType.contractor,
        roles: [role],
      );
    }

    test('contractor owner loads membership without collectionGroup', () async {
      const uid = 'p1YZMXi4GlgHFbCqZQyAjVy2uYD2';
      MockStore.instance.setDemoMembership(
        _membership(
          uid: uid,
          orgId: uid,
          role: EnterpriseRole.contractorCompanyOwner,
        ),
      );

      final memberships = await repo.watchMembershipsForUser(uid).first;
      expect(memberships, hasLength(1));
      expect(memberships.first.hasRole(EnterpriseRole.contractorCompanyOwner), isTrue);
    });

    test('procurement loads membership for org from profile hint', () async {
      const uid = 'proc-uid';
      const orgId = 'big-contractor-org';
      MockStore.instance.setDemoMembership(
        _membership(
          uid: uid,
          orgId: orgId,
          role: EnterpriseRole.procurementManager,
        ),
      );

      final memberships = await repo.watchMembershipsForUser(uid).first;
      expect(memberships.single.orgId, orgId);
    });

    test('engineer loads assigned org membership', () async {
      const uid = 'engineer-uid';
      const orgId = 'big-contractor-org';
      MockStore.instance.setDemoMembership(
        _membership(
          uid: uid,
          orgId: orgId,
          role: EnterpriseRole.engineer,
        ),
      );

      final memberships = await repo.watchMembershipsForUser(uid).first;
      expect(memberships.single.hasRole(EnterpriseRole.engineer), isTrue);
    });

    test('supplier owner loads membership', () async {
      const uid = 'supplier-owner';
      MockStore.instance.setDemoMembership(
        Membership(
          uid: uid,
          orgId: uid,
          orgType: OrganizationType.supplier,
          roles: const [EnterpriseRole.supplierOwner],
        ),
      );

      final memberships = await repo.watchMembershipsForUser(uid).first;
      expect(memberships.single.hasRole(EnterpriseRole.supplierOwner), isTrue);
    });
  });

  group('Platform access without org membership', () {
    test('platformAdmin has access without memberships', () {
      final user = AppUser(
        id: 'admin-uid',
        fullName: 'Admin',
        email: 'admin@admin.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      );

      expect(
        EffectivePermissions.hasPlatformAccess(
          user: user,
          memberships: const [],
          customClaims: const {'platformAdmin': true},
        ),
        isTrue,
      );
    });

    test('active user without membership has no platform access', () {
      final user = AppUser(
        id: 'pending-user',
        fullName: 'Pending',
        email: 'pending@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      );

      expect(
        EffectivePermissions.hasPlatformAccess(
          user: user,
          memberships: const [],
        ),
        isFalse,
      );
    });
  });
}
