import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/providers/enterprise_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// HIGH-7 regression: viewFinancialData must actually gate monetary
/// displays. canViewFinancialDataProvider is the single source of truth the
/// dashboard/chart/project-workspace screens now check.
void main() {
  Membership membership(EnterpriseRole role) => Membership(
        uid: 'u1',
        orgId: 'org1',
        orgType: OrganizationType.contractor,
        roles: [role],
      );

  test('private customer with no org membership always sees their own data',
      () async {
    final container = ProviderContainer(overrides: [
      currentUserMembershipsProvider.overrideWith(
        (ref) => Stream.value(const []),
      ),
      effectivePermissionsProvider.overrideWithValue(const {}),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserMembershipsProvider.future);
    expect(container.read(canViewFinancialDataProvider), isTrue);
  });

  test('engineer (no viewFinancialData) does not see company financial data',
      () async {
    final container = ProviderContainer(overrides: [
      currentUserMembershipsProvider.overrideWith(
        (ref) => Stream.value([membership(EnterpriseRole.engineer)]),
      ),
      effectivePermissionsProvider.overrideWithValue(const {
        Permission.viewOrganization,
        Permission.viewProjects,
        Permission.viewRfqs,
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserMembershipsProvider.future);
    expect(container.read(canViewFinancialDataProvider), isFalse);
  });

  test('procurementManager (has viewFinancialData) sees company financial data',
      () async {
    final container = ProviderContainer(overrides: [
      currentUserMembershipsProvider.overrideWith(
        (ref) => Stream.value([membership(EnterpriseRole.procurementManager)]),
      ),
      effectivePermissionsProvider.overrideWithValue(const {
        Permission.viewOrganization,
        Permission.viewFinancialData,
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserMembershipsProvider.future);
    expect(container.read(canViewFinancialDataProvider), isTrue);
  });

  test('supplierOperations (no viewFinancialData) does not see revenue data',
      () async {
    final container = ProviderContainer(overrides: [
      currentUserMembershipsProvider.overrideWith(
        (ref) => Stream.value([
          Membership(
            uid: 'u1',
            orgId: 'org1',
            orgType: OrganizationType.supplier,
            roles: [EnterpriseRole.supplierOperations],
          ),
        ]),
      ),
      effectivePermissionsProvider.overrideWithValue(const {
        Permission.viewOrganization,
        Permission.viewOrders,
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(currentUserMembershipsProvider.future);
    expect(container.read(canViewFinancialDataProvider), isFalse);
  });
}
