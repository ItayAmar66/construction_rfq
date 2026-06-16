import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuoteService quoteService;

  const orgId = 'org-big';
  const engineerId = 'eng-1';
  const procurementId = 'proc-1';
  const otherOrgProcId = 'proc-other';

  final engineer = AppUser(
    id: engineerId,
    fullName: 'מהנדס QA',
    email: 'qa.contractor.big.engineer@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
  );

  final procurement = AppUser(
    id: procurementId,
    fullName: 'רכש QA',
    email: 'qa.contractor.big.procurement@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
  );

  Membership engineerMembership() => Membership(
        uid: engineerId,
        orgId: orgId,
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.engineer],
      );

  Membership procurementMembership() => Membership(
        uid: procurementId,
        orgId: orgId,
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
      );

  Membership otherOrgProcMembership() => Membership(
        uid: otherOrgProcId,
        orgId: 'org-other',
        orgType: OrganizationType.contractor,
        roles: const [EnterpriseRole.procurementManager],
      );

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    quoteService = QuoteService();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  Future<String> createPendingApprovalRequest() async {
    return quoteService.submitQuoteRequest(
      customer: engineer,
      requestItems: const [
        QuoteRequestItem(
          id: 'line-1',
          quoteRequestId: '',
          productId: 'manual-1',
          productName: 'בלוק 20',
          category: 'בלוקים',
          unitType: 'יחידה',
          quantity: 2,
        ),
      ],
      submitStatus: QuoteRequestStatus.pendingApproval,
      contractorOrgId: orgId,
    );
  }

  test('procurement approves and sends engineer request to suppliers', () async {
    final requestId = await createPendingApprovalRequest();

    await quoteService.approveProcurementRequest(
      requestId: requestId,
      actorUid: procurementId,
      orgId: orgId,
    );

    await quoteService.sendPendingApprovalToSuppliers(
      requestId: requestId,
      actorUid: procurementId,
      memberships: [procurementMembership()],
      orgId: orgId,
      invitedSupplierOrgIds: const ['supplier-org-1'],
    );

    final saved = MockStore.instance.getRequest(requestId)!;
    expect(saved.status, QuoteRequestStatus.sent);
    expect(saved.customerId, engineerId);
    expect(saved.submittedByUid, procurementId);
    expect(saved.invitedSupplierOrgIds, contains('supplier-org-1'));
  });

  test('engineer cannot send approved request to suppliers', () async {
    final requestId = await createPendingApprovalRequest();
    await quoteService.approveProcurementRequest(
      requestId: requestId,
      actorUid: procurementId,
      orgId: orgId,
    );

    expect(
      () => quoteService.sendPendingApprovalToSuppliers(
        requestId: requestId,
        actorUid: engineerId,
        memberships: [engineerMembership()],
        orgId: orgId,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('cross-org procurement cannot send engineer request', () async {
    final requestId = await createPendingApprovalRequest();
    await quoteService.approveProcurementRequest(
      requestId: requestId,
      actorUid: procurementId,
      orgId: orgId,
    );

    expect(
      () => quoteService.sendPendingApprovalToSuppliers(
        requestId: requestId,
        actorUid: otherOrgProcId,
        memberships: [otherOrgProcMembership()],
        orgId: 'org-other',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
