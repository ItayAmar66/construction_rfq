import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/auth_session.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/customer_requests_access.dart';
import 'package:construction_rfq/utils/platform_access_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('customer requests bootstrap', () {
    ProviderContainer containerWith({
      required AuthSession session,
      List<Membership> memberships = const [],
    }) {
      return ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith((ref) => Stream.value(session)),
          resolvedAuthSessionProvider.overrideWith(
            (ref) => AsyncValue.data(session),
          ),
          authBootstrapSettledProvider.overrideWithValue(true),
          membershipBootstrapSettledProvider.overrideWithValue(true),
          currentUserMembershipsProvider.overrideWith(
            (ref) => Stream.value(memberships),
          ),
        ],
      );
    }

    test('no membership user resolves to no-permission gate', () {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      addTearDown(() => AppMode.isDemoMode = false);

      final container = containerWith(
        session: AuthSession(
          uid: 'lonely-user',
          profile: AppUser(
            id: 'lonely-user',
            fullName: 'משתמש ללא שיוך',
            email: 'lonely@test.com',
            phone: '050',
            userType: UserType.commercialCustomer,
            city: 'תל אביב',
            createdAt: DateTime(2026),
          ),
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(platformAccessGateProvider),
        PlatformAccessGate.noPermission,
      );
    });

    test('active contractor with no RFQs gets empty requests list', () async {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      const uid = 'owner-qa';
      addTearDown(() => AppMode.isDemoMode = false);

      final container = containerWith(
        session: AuthSession(
          uid: uid,
          profile: AppUser(
            id: uid,
            fullName: 'בעלים QA',
            email: 'qa.contractor.small.owner@test.com',
            phone: '050',
            userType: UserType.commercialCustomer,
            city: 'תל אביב',
            createdAt: DateTime(2026),
          ),
        ),
        memberships: [
          Membership(
            uid: uid,
            orgId: 'org-small',
            orgType: OrganizationType.contractor,
            roles: const [EnterpriseRole.contractorCompanyOwner],
            status: 'active',
          ),
        ],
      );
      addTearDown(container.dispose);

      final requests =
          await container.read(customerRequestsProvider.future);
      expect(requests, isEmpty);
      final memberships =
          await container.read(currentUserMembershipsProvider.future);
      expect(memberships, isNotEmpty);
      expect(container.read(hasPlatformAccessProvider), isTrue);
      expect(
        container.read(platformAccessGateProvider),
        PlatformAccessGate.granted,
      );
    });

    test('pending user resolves pending gate without hanging', () {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      addTearDown(() => AppMode.isDemoMode = false);

      final container = containerWith(
        session: AuthSession(
          uid: 'pending-user',
          profile: AppUser(
            id: 'pending-user',
            fullName: 'ממתין',
            email: 'pending@test.com',
            phone: '050',
            userType: UserType.commercialCustomer,
            city: 'תל אביב',
            createdAt: DateTime(2026),
            accountStatus: AccountStatus.pendingApproval,
          ),
        ),
      );
      addTearDown(container.dispose);

      expect(
        container.read(platformAccessGateProvider),
        PlatformAccessGate.pendingApproval,
      );
    });

    test('customer requests stream emits immediately in demo mode', () async {
      AppMode.enableDemoMode();
      MockStore.instance.init();
      addTearDown(() => AppMode.isDemoMode = false);

      final first = await MockStore.instance
          .watchCustomerRequests('cust-1')
          .first
          .timeout(const Duration(seconds: 2));
      expect(first, isEmpty);
    });
  });

  test('CustomerRequestsAccessDenied is distinct access error', () {
    expect(const CustomerRequestsAccessDenied(), isA<Exception>());
  });
}
