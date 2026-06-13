import 'package:construction_rfq/models/account_status.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/effective_permissions.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/role_invitation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _customer({AccountStatus status = AccountStatus.active}) {
  return AppUser(
    id: 'c1',
    fullName: 'קבלן',
    email: 'c@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
    accountStatus: status,
  );
}

Membership _membership(EnterpriseRole role) {
  return Membership(
    uid: 'u1',
    orgId: 'org1',
    orgType: OrganizationType.contractor,
    roles: [role],
  );
}

void main() {
  group('approval gating', () {
    test('pending registered user cannot submit RFQ', () {
      expect(
        EffectivePermissions.canSubmitRfq(
          _customer(status: AccountStatus.pendingApproval),
        ),
        isFalse,
      );
      expect(
        EffectivePermissions.hasPlatformAccess(
          user: _customer(status: AccountStatus.pendingApproval),
        ),
        isFalse,
      );
    });

    test('active company manager can use company actions', () {
      expect(
        EffectivePermissions.hasPlatformAccess(
          user: _customer(),
          memberships: [_membership(EnterpriseRole.contractorCompanyOwner)],
        ),
        isTrue,
      );
      expect(
        EffectivePermissions.canSubmitRfq(
          _customer(),
          memberships: [_membership(EnterpriseRole.contractorCompanyOwner)],
        ),
        isTrue,
      );
    });

    test('legacy commercial customer without membership cannot self-serve', () {
      expect(EffectivePermissions.canSubmitRfq(_customer()), isFalse);
      expect(
        EffectivePermissions.resolve(user: _customer()),
        contains(Permission.viewCatalog),
      );
    });
  });

  group('contractor hierarchy', () {
    test('manager can assign procurement and engineer', () {
      final roles = RoleInvitationPolicy.assignableRoles(
        orgType: OrganizationType.contractor,
        actorRoles: const [EnterpriseRole.contractorCompanyOwner],
      );
      expect(roles, contains(EnterpriseRole.procurementManager));
      expect(roles, contains(EnterpriseRole.engineer));
    });

    test('procurement can add engineer only', () {
      final roles = RoleInvitationPolicy.assignableRoles(
        orgType: OrganizationType.contractor,
        actorRoles: const [EnterpriseRole.procurementManager],
      );
      expect(roles, equals(const [
        EnterpriseRole.engineer,
        EnterpriseRole.contractorViewer,
      ]));
    });

    test('procurement cannot add manager or procurement', () {
      expect(
        RoleInvitationPolicy.canAssignRole(
          orgType: OrganizationType.contractor,
          actorRoles: const [EnterpriseRole.procurementManager],
          targetRole: EnterpriseRole.contractorCompanyOwner,
        ),
        isFalse,
      );
      expect(
        RoleInvitationPolicy.canAssignRole(
          orgType: OrganizationType.contractor,
          actorRoles: const [EnterpriseRole.procurementManager],
          targetRole: EnterpriseRole.procurementManager,
        ),
        isFalse,
      );
    });

    test('engineer cannot add users', () {
      expect(
        RoleInvitationPolicy.assignableRoles(
          orgType: OrganizationType.contractor,
          actorRoles: const [EnterpriseRole.engineer],
        ),
        isEmpty,
      );
    });
  });

  group('engineer RFQ flow labels', () {
    test('engineer submit uses procurement approval copy', () {
      expect(
        HebrewStrings.submitForProcurementApproval,
        'שלח לאישור רכש',
      );
      expect(
        QuoteRequestStatus.pendingApproval.label,
        'ממתין לאישור רכש',
      );
      expect(
        QuoteRequestStatus.procurementApproved.label,
        'אושר על ידי רכש',
      );
    });

    test('engineer cannot approve procurement RFQ', () {
      expect(
        EffectivePermissions.canApproveProcurementRfq(
          _customer(),
          memberships: [_membership(EnterpriseRole.engineer)],
        ),
        isFalse,
      );
    });

    test('procurement can approve engineer request', () {
      expect(
        EffectivePermissions.canApproveProcurementRfq(
          _customer(),
          memberships: [_membership(EnterpriseRole.procurementManager)],
        ),
        isTrue,
      );
    });
  });

  group('supplier launch hierarchy', () {
    test('supplier owner can add procurement role', () {
      expect(
        RoleInvitationPolicy.canAssignRole(
          orgType: OrganizationType.supplier,
          actorRoles: const [EnterpriseRole.supplierOwner],
          targetRole: EnterpriseRole.supplierSalesRep,
        ),
        isTrue,
      );
    });

    test('supplier procurement can submit quote', () {
      final supplier = AppUser(
        id: 's1',
        fullName: 'ספק',
        email: 's@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'חיפה',
        createdAt: DateTime(2026),
      );
      expect(
        EffectivePermissions.canCreateSupplierQuote(
          supplier,
          memberships: [_membership(EnterpriseRole.supplierSalesRep)],
        ),
        isTrue,
      );
    });

    test('supplier procurement cannot manage users', () {
      final supplier = AppUser(
        id: 's1',
        fullName: 'ספק',
        email: 's@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'חיפה',
        createdAt: DateTime(2026),
      );
      expect(
        EffectivePermissions.canManageOrgUsers(
          supplier,
          memberships: [_membership(EnterpriseRole.supplierSalesRep)],
        ),
        isFalse,
      );
    });
  });
}
