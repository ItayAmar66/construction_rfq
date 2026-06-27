import 'dart:io';

import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/receipt_checklist_item.dart';
import 'package:construction_rfq/models/receipt_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/shipment_receipt_access.dart';
import 'package:construction_rfq/utils/shipment_receipt_helpers.dart';
import 'package:construction_rfq/utils/shipment_receipt_validation.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const orgId = 'org-alpha';
  const otherOrgId = 'org-beta';

  late QuoteService quoteService;

  final engineer = AppUser(
    id: 'eng-1',
    fullName: 'Engineer',
    email: 'eng@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'TLV',
    createdAt: DateTime(2026),
  );

  final procurement = AppUser(
    id: 'proc-1',
    fullName: 'Procurement',
    email: 'proc@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'TLV',
    createdAt: DateTime(2026),
  );

  final owner = AppUser(
    id: 'owner-1',
    fullName: 'Owner',
    email: 'owner@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'TLV',
    createdAt: DateTime(2026),
  );

  final viewer = AppUser(
    id: 'viewer-1',
    fullName: 'Viewer',
    email: 'viewer@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'TLV',
    createdAt: DateTime(2026),
  );

  final supplier = AppUser(
    id: 'sup-1',
    fullName: 'Supplier',
    email: 'sup@test.com',
    phone: '050',
    userType: UserType.commercialSupplier,
    city: 'TLV',
    createdAt: DateTime(2026),
  );

  final otherContractor = AppUser(
    id: 'other-1',
    fullName: 'Other',
    email: 'other@test.com',
    phone: '050',
    userType: UserType.commercialCustomer,
    city: 'TLV',
    createdAt: DateTime(2026),
  );

  Membership membership(String uid, EnterpriseRole role, {String org = orgId}) =>
      Membership(
        uid: uid,
        orgId: org,
        orgType: OrganizationType.contractor,
        roles: [role],
      );

  QuoteRequestItem line(String id, {int qty = 2}) => QuoteRequestItem(
        id: id,
        quoteRequestId: '',
        productId: 'p_$id',
        productName: 'Product $id',
        category: 'Cat',
        unitType: 'יחידה',
        quantity: qty,
      );

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
    quoteService = QuoteService();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  Future<({String requestId, String quoteId})> seedApprovedOrder() async {
    final requestId = await quoteService.submitQuoteRequest(
      customer: engineer,
      requestItems: [line('a'), line('b')],
      submitStatus: QuoteRequestStatus.sent,
      contractorOrgId: orgId,
    );
    final quoteId = await quoteService.submitSupplierQuote(
      supplier: supplier,
      quoteRequestId: requestId,
      deliveryTime: '2 ימים',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: line('a'),
          unitPrice: 10,
          requestedQuantity: 2,
          includeInQuote: true,
          isExactMatch: true,
        ),
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: line('b'),
          unitPrice: 20,
          requestedQuantity: 2,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );
    await quoteService.approveCustomerQuote(
      quoteId: quoteId,
      requestId: requestId,
      actorUid: procurement.id,
      memberships: [membership(procurement.id, EnterpriseRole.procurementManager)],
      orgId: orgId,
    );
    await quoteService.markSupplierOrderShipped(
      quoteId: quoteId,
      requestId: requestId,
      supplierId: supplier.id,
    );
    return (requestId: requestId, quoteId: quoteId);
  }

  group('Shipment receipt flow', () {
    test('supplier marks shipped then request is pending receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      expect(request.status, QuoteRequestStatus.pendingReceipt);
      expect(request.receiptStatus, ReceiptStatus.pendingReceipt);
    });

    test('contractor confirms full receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      final checklist = ShipmentReceiptHelpers.initialChecklistFromRequest(request);

      await quoteService.confirmShipmentReceipt(
        requestId: seeded.requestId,
        actorUid: procurement.id,
        checklist: checklist,
        fullReceipt: true,
        memberships: [membership(procurement.id, EnterpriseRole.procurementManager)],
        orgId: orgId,
      );

      final updated = MockStore.instance.getRequest(seeded.requestId)!;
      expect(updated.status, QuoteRequestStatus.receivedFull);
      expect(updated.receiptStatus, ReceiptStatus.receivedFull);
    });

    test('engineer can confirm receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      await quoteService.confirmShipmentReceipt(
        requestId: seeded.requestId,
        actorUid: engineer.id,
        checklist: ShipmentReceiptHelpers.initialChecklistFromRequest(request),
        fullReceipt: true,
        memberships: [membership(engineer.id, EnterpriseRole.engineer)],
        orgId: orgId,
      );
      expect(
        MockStore.instance.getRequest(seeded.requestId)!.receiptStatus,
        ReceiptStatus.receivedFull,
      );
    });

    test('owner can confirm receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      await quoteService.confirmShipmentReceipt(
        requestId: seeded.requestId,
        actorUid: owner.id,
        checklist: ShipmentReceiptHelpers.initialChecklistFromRequest(request),
        fullReceipt: true,
        memberships: [membership(owner.id, EnterpriseRole.contractorCompanyOwner)],
        orgId: orgId,
      );
      expect(
        MockStore.instance.getRequest(seeded.requestId)!.receiptStatus,
        ReceiptStatus.receivedFull,
      );
    });

    test('issue receipt flow stores checklist and status', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      final checklist = ShipmentReceiptHelpers.initialChecklistFromRequest(request);
      final withIssue = checklist.first.copyWith(
        receivedQuantity: 1,
        condition: ReceiptItemCondition.missingQuantity,
        issueNotes: 'חסרה יחידה',
        updateIssueNotes: true,
      );

      await quoteService.confirmShipmentReceipt(
        requestId: seeded.requestId,
        actorUid: procurement.id,
        checklist: [withIssue, ...checklist.skip(1)],
        fullReceipt: false,
        memberships: [membership(procurement.id, EnterpriseRole.procurementManager)],
        orgId: orgId,
      );

      final updated = MockStore.instance.getRequest(seeded.requestId)!;
      expect(updated.status, QuoteRequestStatus.receivedWithIssues);
      expect(updated.receiptStatus, ReceiptStatus.receivedWithIssues);
      expect(updated.receiptChecklist.first.condition,
          ReceiptItemCondition.missingQuantity);
    });
  });

  group('Shipment receipt negatives', () {
    test('supplier cannot confirm receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      expect(
        () => quoteService.confirmShipmentReceipt(
          requestId: seeded.requestId,
          actorUid: supplier.id,
          checklist: ShipmentReceiptHelpers.initialChecklistFromRequest(request),
          fullReceipt: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('viewer cannot confirm receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      expect(
        ShipmentReceiptAccess.canConfirmReceiptForRequest(
          actorUid: viewer.id,
          request: request,
          memberships: [membership(viewer.id, EnterpriseRole.contractorViewer)],
          orgId: orgId,
        ),
        isFalse,
      );
    });

    test('different contractor org cannot confirm receipt', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      expect(
        () => quoteService.confirmShipmentReceipt(
          requestId: seeded.requestId,
          actorUid: otherContractor.id,
          checklist: ShipmentReceiptHelpers.initialChecklistFromRequest(request),
          fullReceipt: true,
          memberships: [
            membership(otherContractor.id, EnterpriseRole.procurementManager,
                org: otherOrgId),
          ],
          orgId: otherOrgId,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('cannot confirm before shipped', () async {
      final requestId = await quoteService.submitQuoteRequest(
        customer: engineer,
        requestItems: [line('x')],
        submitStatus: QuoteRequestStatus.sent,
        contractorOrgId: orgId,
      );
      final request = MockStore.instance.getRequest(requestId)!;
      expect(
        () => quoteService.confirmShipmentReceipt(
          requestId: requestId,
          actorUid: procurement.id,
          checklist: ShipmentReceiptHelpers.initialChecklistFromRequest(request),
          fullReceipt: true,
          memberships: [membership(procurement.id, EnterpriseRole.procurementManager)],
          orgId: orgId,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('cannot confirm twice', () async {
      final seeded = await seedApprovedOrder();
      final request = MockStore.instance.getRequest(seeded.requestId)!;
      final checklist = ShipmentReceiptHelpers.initialChecklistFromRequest(request);
      await quoteService.confirmShipmentReceipt(
        requestId: seeded.requestId,
        actorUid: procurement.id,
        checklist: checklist,
        fullReceipt: true,
        memberships: [membership(procurement.id, EnterpriseRole.procurementManager)],
        orgId: orgId,
      );
      expect(
        () => quoteService.confirmShipmentReceipt(
          requestId: seeded.requestId,
          actorUid: procurement.id,
          checklist: checklist,
          fullReceipt: true,
          memberships: [membership(procurement.id, EnterpriseRole.procurementManager)],
          orgId: orgId,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Validation', () {
    test('full receipt button logic requires all ok quantities', () {
      final items = [
        ReceiptChecklistItem(
          itemId: '1',
          productName: 'A',
          orderedQuantity: 2,
          receivedQuantity: 2,
        ),
        ReceiptChecklistItem(
          itemId: '2',
          productName: 'B',
          orderedQuantity: 3,
          receivedQuantity: 2,
          condition: ReceiptItemCondition.missingQuantity,
        ),
      ];
      expect(ShipmentReceiptValidation.isFullReceipt(items), isFalse);
      expect(
        () => ShipmentReceiptValidation.validateFullReceiptSubmit(items),
        throwsA(isA<ShipmentReceiptValidationException>()),
      );
    });

    test('mark all ok sets quantities and status', () {
      final items = [
        ReceiptChecklistItem(
          itemId: '1',
          productName: 'A',
          orderedQuantity: 4,
          receivedQuantity: 0,
          condition: ReceiptItemCondition.notReceived,
        ),
      ];
      final ok = ShipmentReceiptValidation.markAllOk(items);
      expect(ok.first.receivedQuantity, 4);
      expect(ok.first.condition, ReceiptItemCondition.ok);
    });
  });

  group('Firestore receipt rules', () {
    final rules =
        File('${Directory.current.path}/firestore.rules').readAsStringSync();

    test('includes receipt confirmation helpers', () {
      expect(rules, contains('contractorReceiptConfirmationAllowed()'));
      expect(rules, contains('customerReceiptConfirmationAllowed()'));
      expect(rules, contains('canConfirmReceiptForRequest'));
      expect(rules, contains('pending_receipt'));
      expect(rules, contains('received_full'));
      expect(rules, contains('received_with_issues'));
      expect(rules, contains('ממתין לאישור קבלה'));
    });
  });
}
