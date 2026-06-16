import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuoteService quoteService;

  const bigSupplierOrgId = 'qa-supplier-big';
  const bigSupplierOwnerId = 'sup-big-owner';
  const bigSupplierProcId = 'sup-big-proc';

  QuoteRequestItem line() => const QuoteRequestItem(
        id: 'line-1',
        quoteRequestId: '',
        productId: 'manual-1',
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        quantity: 2,
      );

  AppUser supplierUser(String id, String orgId) => AppUser(
        id: id,
        fullName: 'QA Big Supplier',
        email: '$id@test.com',
        phone: '050',
        userType: UserType.commercialSupplier,
        city: 'תל אביב',
        createdAt: DateTime(2026),
        supplierOrgId: orgId,
      );

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    quoteService = QuoteService();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  Future<String> createApprovedOrder({
    required String submitterId,
    required String orgId,
  }) async {
    final requestId = await quoteService.submitQuoteRequest(
      customer: AppUser(
        id: 'customer-1',
        fullName: 'Customer',
        email: 'c@test.com',
        phone: '050',
        userType: UserType.commercialCustomer,
        city: 'תל אביב',
        createdAt: DateTime(2026),
      ),
      requestItems: [line()],
      submitStatus: QuoteRequestStatus.sent,
      invitedSupplierOrgIds: const [bigSupplierOrgId],
    );

    final quoteId = await quoteService.submitSupplierQuote(
      supplier: supplierUser(submitterId, orgId),
      quoteRequestId: requestId,
      deliveryTime: '7 ימים',
      lines: [
        SupplierQuoteLineMapper.fromRequestLine(
          requestItem: line(),
          unitPrice: 12345,
          requestedQuantity: line().quantity,
          includeInQuote: true,
        ),
      ],
      supplierOrgId: orgId,
    );

    await quoteService.approveCustomerQuote(
      quoteId: quoteId,
      requestId: requestId,
      actorUid: 'customer-1',
    );
    return quoteId;
  }

  test('approved big supplier order appears for org owner', () async {
    await createApprovedOrder(
      submitterId: bigSupplierProcId,
      orgId: bigSupplierOrgId,
    );

    final orders = await quoteService
        .watchSupplierOrdersToFulfill(
          bigSupplierOwnerId,
          supplierOrgId: bigSupplierOrgId,
        )
        .first;

    expect(orders, isNotEmpty);
    expect(orders.first.supplierOrgId, bigSupplierOrgId);
  });

  test('mark נשלחה succeeds for approved supplier org member', () async {
    final quoteId = await createApprovedOrder(
      submitterId: bigSupplierProcId,
      orgId: bigSupplierOrgId,
    );
    final requestId = MockStore.instance.supplierQuotes
        .firstWhere((q) => q.id == quoteId)
        .quoteRequestId;

    await quoteService.markSupplierOrderShipped(
      quoteId: quoteId,
      requestId: requestId,
      supplierId: bigSupplierOwnerId,
      supplierOrgId: bigSupplierOrgId,
    );

    final history = await quoteService
        .watchSupplierOrderHistory(
          bigSupplierOwnerId,
          supplierOrgId: bigSupplierOrgId,
        )
        .first;
    expect(history.any((q) => q.id == quoteId), isTrue);

    final pending = await quoteService
        .watchSupplierOrdersToFulfill(
          bigSupplierOwnerId,
          supplierOrgId: bigSupplierOrgId,
        )
        .first;
    expect(pending.any((q) => q.id == quoteId), isFalse);
  });

  test('unapproved supplier cannot ship org order', () async {
    final quoteId = await createApprovedOrder(
      submitterId: bigSupplierProcId,
      orgId: bigSupplierOrgId,
    );
    final requestId = MockStore.instance.supplierQuotes
        .firstWhere((q) => q.id == quoteId)
        .quoteRequestId;

    expect(
      () => quoteService.markSupplierOrderShipped(
        quoteId: quoteId,
        requestId: requestId,
        supplierId: 'random-user',
        supplierOrgId: 'other-org',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
