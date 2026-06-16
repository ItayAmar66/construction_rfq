import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/quote_financials.dart';
import 'package:construction_rfq/utils/supplier_quote_line_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuoteService quoteService;

  const bigSupplierOrgId = 'qa-supplier-big';
  const bigSupplierOwnerId = 'sup-big-owner';
  const smallSupplierOrgId = 'qa-supplier-small';
  const smallSupplierOwnerId = 'sup-small-owner';

  QuoteRequestItem line() => const QuoteRequestItem(
        id: 'line-1',
        quoteRequestId: '',
        productId: 'manual-1',
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        quantity: 2,
      );

  SupplierQuoteLineInput pricedLine(double unitPrice) =>
      SupplierQuoteLineMapper.fromRequestLine(
        requestItem: line(),
        unitPrice: unitPrice,
        requestedQuantity: line().quantity,
        includeInQuote: true,
      );

  AppUser supplier({
    required String id,
    required String name,
    required String orgId,
  }) =>
      AppUser(
        id: id,
        fullName: name,
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

  Future<String> createTargetedRequest() {
    return quoteService.submitQuoteRequest(
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
      invitedSupplierOrgIds: const [bigSupplierOrgId, smallSupplierOrgId],
      invitedSupplierNames: const ['QA Big', 'QA Small'],
    );
  }

  test('footer total updates from line prices via financial breakdown', () {
    final breakdown = QuoteFinancialBreakdown.compute(
      subtotal: 12345,
      deliveryCost: 0,
      vatRate: QuoteFinancialBreakdown.defaultVatRate,
    );
    expect(breakdown.totalInclVat, greaterThan(12345));
  });

  test('big supplier quote submit succeeds on QA-targeted RFQ', () async {
    final requestId = await createTargetedRequest();
    final quoteId = await quoteService.submitSupplierQuote(
      supplier: supplier(
        id: bigSupplierOwnerId,
        name: 'QA Big',
        orgId: bigSupplierOrgId,
      ),
      quoteRequestId: requestId,
      deliveryTime: '7 ימים',
      lines: [pricedLine(12345)],
      supplierOrgId: bigSupplierOrgId,
    );

    expect(quoteId, isNotEmpty);
    final quote = MockStore.instance.supplierQuotes
        .firstWhere((q) => q.id == quoteId);
    expect(quote.supplierOrgId, bigSupplierOrgId);
    expect(quote.totalInclVat, greaterThan(0));
  });

  test('small supplier quote submit succeeds on same QA-targeted RFQ', () async {
    final requestId = await createTargetedRequest();
    await quoteService.submitSupplierQuote(
      supplier: supplier(
        id: bigSupplierOwnerId,
        name: 'QA Big',
        orgId: bigSupplierOrgId,
      ),
      quoteRequestId: requestId,
      deliveryTime: '7 ימים',
      lines: [pricedLine(12000)],
      supplierOrgId: bigSupplierOrgId,
    );

    final quoteId = await quoteService.submitSupplierQuote(
      supplier: supplier(
        id: smallSupplierOwnerId,
        name: 'QA Small',
        orgId: smallSupplierOrgId,
      ),
      quoteRequestId: requestId,
      deliveryTime: '5 ימים',
      lines: [pricedLine(12990)],
      supplierOrgId: smallSupplierOrgId,
    );
    expect(quoteId, isNotEmpty);
  });

  test('duplicate quote same org denied', () async {
    final requestId = await createTargetedRequest();
    final big = supplier(
      id: bigSupplierOwnerId,
      name: 'QA Big',
      orgId: bigSupplierOrgId,
    );
    await quoteService.submitSupplierQuote(
      supplier: big,
      quoteRequestId: requestId,
      deliveryTime: '7 ימים',
      lines: [pricedLine(100)],
      supplierOrgId: bigSupplierOrgId,
    );

    expect(
      () => quoteService.submitSupplierQuote(
        supplier: big,
        quoteRequestId: requestId,
        deliveryTime: '7 ימים',
        lines: [pricedLine(200)],
        supplierOrgId: bigSupplierOrgId,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('uninvited supplier quote denied with clear message', () async {
    final requestId = await createTargetedRequest();
    expect(
      () => quoteService.submitSupplierQuote(
        supplier: supplier(
          id: 'other-supplier',
          name: 'Other',
          orgId: 'other-org',
        ),
        quoteRequestId: requestId,
        deliveryTime: '7 ימים',
        lines: [pricedLine(100)],
        supplierOrgId: 'other-org',
      ),
      throwsA(
        predicate(
          (e) =>
              e is Exception &&
              e.toString().contains('אין הרשאה להגיש הצעה'),
        ),
      ),
    );
  });
}
