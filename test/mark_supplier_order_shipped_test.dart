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
import 'package:flutter_test/flutter_test.dart';

/// HIGH-8 regression: markSupplierOrderShipped must reject a quote/request
/// pair that don't actually belong together, closing the cross-request
/// corruption a supplier could previously trigger by crafting a
/// `/supplier/order/` URL with their own quote id but an unrelated
/// requestId query parameter.
void main() {
  const orgId = 'org-alpha';
  late QuoteService quoteService;

  final procurement = AppUser(
    id: 'proc-1',
    fullName: 'Procurement',
    email: 'proc@test.com',
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

  QuoteRequestItem line(String id) => QuoteRequestItem(
        id: id,
        quoteRequestId: '',
        productId: 'p_$id',
        productName: 'Product $id',
        category: 'Cat',
        unitType: 'יחידה',
        quantity: 1,
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

  Future<({String requestId, String quoteId})> seedApprovedOrder(
    String tag,
  ) async {
    final requestId = await quoteService.submitQuoteRequest(
      customer: procurement,
      requestItems: [line(tag)],
      submitStatus: QuoteRequestStatus.sent,
      contractorOrgId: orgId,
    );
    final quoteId = await quoteService.submitSupplierQuote(
      supplier: supplier,
      quoteRequestId: requestId,
      deliveryTime: '2 ימים',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: line(tag),
          unitPrice: 10,
          requestedQuantity: 1,
          includeInQuote: true,
          isExactMatch: true,
        ),
      ],
    );
    await quoteService.approveCustomerQuote(
      quoteId: quoteId,
      requestId: requestId,
      actorUid: procurement.id,
      memberships: [
        Membership(
          uid: procurement.id,
          orgId: orgId,
          orgType: OrganizationType.contractor,
          roles: [EnterpriseRole.procurementManager],
        ),
      ],
      orgId: orgId,
    );
    return (requestId: requestId, quoteId: quoteId);
  }

  group('markSupplierOrderShipped', () {
    test('succeeds when the quote actually belongs to the request', () async {
      final order = await seedApprovedOrder('a');
      await quoteService.markSupplierOrderShipped(
        quoteId: order.quoteId,
        requestId: order.requestId,
        supplierId: supplier.id,
      );
      final updated = MockStore.instance.getRequest(order.requestId)!;
      expect(updated.status, QuoteRequestStatus.pendingReceipt);
    });

    test('rejects a quote/request pair that do not belong together', () async {
      final orderA = await seedApprovedOrder('a');
      final orderB = await seedApprovedOrder('b');

      // Own quote (orderA), but a mismatched, unrelated request (orderB) —
      // exactly the crafted /supplier/order/<quoteId>?requestId=<other> case.
      expect(
        () => quoteService.markSupplierOrderShipped(
          quoteId: orderA.quoteId,
          requestId: orderB.requestId,
          supplierId: supplier.id,
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('אינה שייכת לבקשה'),
          ),
        ),
      );

      // Neither request should have been corrupted by the rejected call.
      expect(
        MockStore.instance.getRequest(orderA.requestId)!.status,
        isNot(QuoteRequestStatus.pendingReceipt),
      );
      expect(
        MockStore.instance.getRequest(orderB.requestId)!.status,
        isNot(QuoteRequestStatus.pendingReceipt),
      );
    });
  });
}
