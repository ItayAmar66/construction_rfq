import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/access_request.dart';
import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/repositories/access_request_repository.dart';
import 'package:construction_rfq/services/user_approval_service.dart';
import 'package:construction_rfq/utils/platform_access_gate.dart';
import 'package:construction_rfq/utils/role_invitation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.enableDemoMode();
    AccessRequestRepository.resetDemo();
  });

  test('pending user resolves to pending approval gate', () {
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

  test('rejected and disabled users use pending gate', () {
    for (final status in [AccountStatus.rejected, AccountStatus.disabled]) {
      expect(
        PlatformAccessGateResolver.resolve(
          isAuthenticated: true,
          membershipSettled: true,
          hasPlatformAccess: false,
          accountStatus: status,
          membershipLoadError: false,
          isPlatformAdmin: false,
        ),
        PlatformAccessGate.pendingApproval,
      );
    }
  });

  test('contractor owner approval roles exclude owner and platform admin', () {
    final roles = UserApprovalService.approvalRolesFor(
      orgType: OrganizationType.contractor,
      actorRoles: [EnterpriseRole.contractorCompanyOwner],
      isPlatformAdmin: false,
    );
    expect(roles, contains(EnterpriseRole.procurementManager));
    expect(roles, isNot(contains(EnterpriseRole.contractorCompanyOwner)));
    expect(roles, isNot(contains(EnterpriseRole.platformAdmin)));
  });

  test('supplier owner approval roles exclude owner', () {
    final roles = UserApprovalService.approvalRolesFor(
      orgType: OrganizationType.supplier,
      actorRoles: [EnterpriseRole.supplierOwner],
      isPlatformAdmin: false,
    );
    expect(roles, contains(EnterpriseRole.supplierSalesRep));
    expect(roles, isNot(contains(EnterpriseRole.supplierOwner)));
  });

  test('procurement cannot assign owner role', () {
    expect(
      RoleInvitationPolicy.canAssignRole(
        orgType: OrganizationType.contractor,
        actorRoles: [EnterpriseRole.procurementManager],
        targetRole: EnterpriseRole.contractorCompanyOwner,
      ),
      isFalse,
    );
  });

  test('access request repository stores pending demo request', () async {
    const request = AccessRequest(
      uid: 'pending-1',
      email: 'new@test.com',
      fullName: 'New User',
      userType: 'commercialCustomer',
      requestedOrgType: OrganizationType.contractor,
      requestedOrgId: 'launch-org-dimri',
      requestedOrgName: 'דימרי',
    );
    final repo = AccessRequestRepository();
    await repo.createPendingRequest(request);
    final pending = await repo.fetchPendingForOrg('launch-org-dimri');
    expect(pending.length, 1);
    expect(pending.first.email, 'new@test.com');
  });
}
