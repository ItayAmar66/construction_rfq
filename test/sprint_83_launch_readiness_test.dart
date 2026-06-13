import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/audit_event.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/enterprise/permission.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/repositories/invitation_repository.dart';
import 'package:construction_rfq/repositories/organization_repository.dart';
import 'package:construction_rfq/repositories/request_repository.dart';
import 'package:construction_rfq/services/enterprise_permission_service.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/user_facing_error.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequestItem _line() => const QuoteRequestItem(
      id: 'l1',
      quoteRequestId: '',
      productId: 'p1',
      productName: 'בלוק',
      category: 'בלוקים',
      unitType: 'יח',
      quantity: 2,
    );

AppUser _customer() => AppUser(
      id: 'cust-s83',
      fullName: 'Test',
      email: 't@test.com',
      phone: '050',
      userType: UserType.commercialCustomer,
      city: 'TLV',
      createdAt: DateTime(2024),
    );

void main() {
  setUp(() {
    AppMode.isDemoMode = true;
    MockStore.instance.init();
    MockStore.instance.demoMemberships.clear();
    MockStore.instance.demoInvitations.clear();
    MockStore.instance.demoAuditEvents.clear();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
  });

  tearDown(() => AppMode.isDemoMode = false);

  test('membership toMap includes uid', () {
    const m = Membership(
      uid: 'user-1',
      orgId: 'org-1',
      orgType: OrganizationType.contractor,
      roles: [EnterpriseRole.engineer],
    );
    expect(m.toMap()['uid'], 'user-1');
  });

  test('accept invitation stores membership uid', () async {
    final invite = await InvitationRepository().createInvitation(
      orgId: 'org-x',
      orgType: OrganizationType.contractor,
      email: 'join@test.local',
      role: EnterpriseRole.engineer,
      invitedByUid: 'owner-1',
      canManage: true,
    );
    await InvitationRepository().acceptInvitation(
      inviteId: invite.id,
      uid: 'new-user',
      email: 'join@test.local',
    );
    expect(MockStore.instance.demoMemberships['new-user']?.uid, 'new-user');
  });

  test('userFacingError maps permission-denied', () {
    expect(
      userFacingError(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      ),
      'אין הרשאה לפעולה זו',
    );
  });

  test('RFQ send writes audit event', () async {
    await RequestRepository().submitQuoteRequest(
      customer: _customer(),
      requestItems: [_line()],
      submitStatus: QuoteRequestStatus.sent,
      projectId: 'p1',
      projectName: 'פרויקט',
    );
    expect(
      MockStore.instance.demoAuditEvents.any((e) => e.action == AuditAction.rfqSent),
      isTrue,
    );
  });

  test('quote approval writes audit event', () async {
    final quoteService = QuoteService();
    final requestId = await quoteService.submitQuoteRequest(
      customer: _customer(),
      requestItems: [_line()],
    );
    final quoteId = await quoteService.submitSupplierQuote(
      supplier: MockStore.demoSupplier,
      quoteRequestId: requestId,
      deliveryTime: '3 days',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: _line(),
          unitPrice: 10,
          requestedQuantity: 2,
          includeInQuote: true,
        ),
      ],
    );
    await quoteService.approveCustomerQuote(
      quoteId: quoteId,
      requestId: requestId,
      customerId: _customer().id,
    );
    expect(
      MockStore.instance.demoAuditEvents
          .any((e) => e.action == AuditAction.quoteApproved),
      isTrue,
    );
  });

  test('last owner role demotion blocked', () async {
    MockStore.instance.demoMemberships['owner-1'] = Membership(
      uid: 'owner-1',
      orgId: 'org-c',
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorCompanyOwner],
    );
    expect(
      () => OrganizationRepository().updateMemberRole(
        orgId: 'org-c',
        memberUid: 'owner-1',
        newRole: EnterpriseRole.engineer,
        actorUid: 'other-1',
        orgType: OrganizationType.contractor,
      ),
      throwsA(isA<Exception>()),
    );
  });

  group('role guardrails', () {
    test('engineer cannot manage company users', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.engineer],
      );
      expect(perms, isNot(contains(Permission.manageUsers)));
    });

    test('procurement can submit RFQ but not manage users', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.procurementManager],
      );
      expect(perms, contains(Permission.submitRfq));
      expect(perms, isNot(contains(Permission.manageUsers)));
    });

    test('supplier sales rep cannot manage supplier users', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.supplierSalesRep],
      );
      expect(perms, isNot(contains(Permission.manageUsers)));
    });

    test('supplier owner can manage supplier users', () {
      final perms = EnterprisePermissionService.permissionsForRoles(
        [EnterpriseRole.supplierOwner],
      );
      expect(perms, contains(Permission.manageUsers));
    });
  });

  test('wrong email cannot accept invitation', () async {
    final invite = await InvitationRepository().createInvitation(
      orgId: 'org-y',
      orgType: OrganizationType.contractor,
      email: 'right@test.local',
      role: EnterpriseRole.engineer,
      invitedByUid: 'owner-1',
      canManage: true,
    );
    expect(
      () => InvitationRepository().acceptInvitation(
        inviteId: invite.id,
        uid: 'other-user',
        email: 'wrong@test.local',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('accepted invitation cannot be reused', () async {
    final invite = await InvitationRepository().createInvitation(
      orgId: 'org-z',
      orgType: OrganizationType.contractor,
      email: 'once@test.local',
      role: EnterpriseRole.engineer,
      invitedByUid: 'owner-1',
      canManage: true,
    );
    await InvitationRepository().acceptInvitation(
      inviteId: invite.id,
      uid: 'user-once',
      email: 'once@test.local',
    );
    expect(
      () => InvitationRepository().acceptInvitation(
        inviteId: invite.id,
        uid: 'user-twice',
        email: 'once@test.local',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
