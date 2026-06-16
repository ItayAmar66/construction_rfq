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
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:construction_rfq/utils/supplier_targeting_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuoteService quoteService;

  const orgId = 'org-big';
  const engineerId = 'eng-1';
  const procurementId = 'proc-1';
  const bigSupplierOrgId = 'qa-supplier-big';
  const smallSupplierOrgId = 'qa-supplier-small';
  const bigSupplierId = 'sup-big-owner';
  const smallSupplierId = 'sup-small-owner';
  const unrelatedSupplierId = 'sup-unrelated';

  final engineer = AppUser(
    id: engineerId,
    fullName: 'מהנדס QA',
    email: 'qa.contractor.big.engineer@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2026),
  );

  QuoteRequestItem line() => const QuoteRequestItem(
        id: 'line-1',
        quoteRequestId: '',
        productId: 'manual-1',
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        quantity: 2,
      );

  Membership procurementMembership() => Membership(
        uid: procurementId,
        orgId: orgId,
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

  Future<String> createPendingApprovalRequest() {
    return quoteService.submitQuoteRequest(
      customer: engineer,
      requestItems: [line()],
      submitStatus: QuoteRequestStatus.pendingApproval,
      contractorOrgId: orgId,
    );
  }

  Future<void> approveAndSendTwoSuppliers(String requestId) async {
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
      invitedSupplierIds: const [bigSupplierId, smallSupplierId],
      invitedSupplierNames: const [
        'QA ספק גדול בע"מ',
        'QA ספק קטן',
      ],
      invitedSupplierOrgIds: const [bigSupplierOrgId, smallSupplierOrgId],
    );
  }

  test('procurement send without suppliers is blocked', () async {
    final requestId = await createPendingApprovalRequest();
    await quoteService.approveProcurementRequest(
      requestId: requestId,
      actorUid: procurementId,
      orgId: orgId,
    );

    expect(
      () => quoteService.sendPendingApprovalToSuppliers(
        requestId: requestId,
        actorUid: procurementId,
        memberships: [procurementMembership()],
        orgId: orgId,
      ),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('יש לבחור לפחות ספק אחד'),
        ),
      ),
    );
  });

  test('procurement send keeps engineer customerId and does not touch customerLastSeenStatus',
      () async {
    final requestId = await createPendingApprovalRequest();
    await quoteService.approveProcurementRequest(
      requestId: requestId,
      actorUid: procurementId,
      orgId: orgId,
    );
    final afterApprove = MockStore.instance.getRequest(requestId)!;

    await quoteService.sendPendingApprovalToSuppliers(
      requestId: requestId,
      actorUid: procurementId,
      memberships: [procurementMembership()],
      orgId: orgId,
      invitedSupplierIds: const [bigSupplierId, smallSupplierId],
      invitedSupplierNames: const [
        'QA ספק גדול בע"מ',
        'QA ספק קטן',
      ],
      invitedSupplierOrgIds: const [bigSupplierOrgId, smallSupplierOrgId],
    );

    final saved = MockStore.instance.getRequest(requestId)!;
    expect(saved.status, QuoteRequestStatus.sent);
    expect(saved.customerId, engineerId);
    expect(saved.submittedByUid, procurementId);
    expect(saved.customerLastSeenStatus, afterApprove.customerLastSeenStatus);
    expect(saved.invitedSupplierOrgIds,
        containsAll([bigSupplierOrgId, smallSupplierOrgId]));
    expect(saved.invitedSupplierIds, containsAll([bigSupplierId, smallSupplierId]));
  });

  test('targeted suppliers see RFQ and unrelated supplier does not', () async {
    final requestId = await createPendingApprovalRequest();
    await approveAndSendTwoSuppliers(requestId);
    final saved = MockStore.instance.getRequest(requestId)!;

    expect(
      SupplierTargetingHelpers.shouldShowToSupplier(
        request: saved,
        supplierId: bigSupplierId,
        supplierOrgId: bigSupplierOrgId,
      ),
      isTrue,
    );
    expect(
      SupplierTargetingHelpers.shouldShowToSupplier(
        request: saved,
        supplierId: smallSupplierId,
        supplierOrgId: smallSupplierOrgId,
      ),
      isTrue,
    );
    expect(
      SupplierTargetingHelpers.shouldShowToSupplier(
        request: saved,
        supplierId: unrelatedSupplierId,
        supplierOrgId: 'other-org',
      ),
      isFalse,
    );
  });

  test('E2E procurement send to two suppliers through approval flow', () async {
    final requestId = await createPendingApprovalRequest();
    await approveAndSendTwoSuppliers(requestId);

    final bigSupplier = AppUser(
      id: bigSupplierId,
      fullName: 'QA ספק גדול בע"מ',
      email: 'qa.supplier.big.owner@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'תל אביב',
      createdAt: DateTime(2026),
      supplierOrgId: bigSupplierOrgId,
    );
    final smallSupplier = AppUser(
      id: smallSupplierId,
      fullName: 'QA ספק קטן',
      email: 'qa.supplier.small.owner@test.com',
      phone: '050',
      userType: UserType.commercialSupplier,
      city: 'חיפה',
      createdAt: DateTime(2026),
      supplierOrgId: smallSupplierOrgId,
    );

    final bigQuoteId = await quoteService.submitSupplierQuote(
      supplier: bigSupplier,
      quoteRequestId: requestId,
      deliveryTime: '2 ימים',
      supplierOrgId: bigSupplierOrgId,
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: line(),
          unitPrice: 40,
          requestedQuantity: 2,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );
    final smallQuoteId = await quoteService.submitSupplierQuote(
      supplier: smallSupplier,
      quoteRequestId: requestId,
      deliveryTime: '3 ימים',
      supplierOrgId: smallSupplierOrgId,
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: line(),
          unitPrice: 45,
          requestedQuantity: 2,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );

    await quoteService.approveCustomerQuote(
      actorUid: procurementId,
      requestId: requestId,
      quoteId: bigQuoteId,
      memberships: [procurementMembership()],
      orgId: orgId,
    );

    expect(
      () => quoteService.approveCustomerQuote(
        actorUid: procurementId,
        requestId: requestId,
        quoteId: smallQuoteId,
        memberships: [procurementMembership()],
        orgId: orgId,
      ),
      throwsA(isA<Exception>()),
    );

    await quoteService.markSupplierOrderShipped(
      quoteId: bigQuoteId,
      requestId: requestId,
      supplierId: bigSupplierId,
    );

    final shipped = await quoteService.watchSupplierQuote(bigQuoteId).first;
    expect(shipped?.status, SupplierQuoteStatus.shipped);
  });
}
