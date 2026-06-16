import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/enterprise/enterprise_role.dart';
import 'package:construction_rfq/models/enterprise/membership.dart';
import 'package:construction_rfq/models/enterprise/organization_type.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/supplier_quote.dart';
import 'package:construction_rfq/models/supplier_quote_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/services/quote_service.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuoteService quoteService;

  const orgId = 'org-big';
  const engineerId = 'eng-1';
  const procurementId = 'proc-1';
  const supplierId = 'sup-1';

  final engineer = AppUser(
    id: engineerId,
    fullName: 'מהנדס',
    email: 'qa.contractor.big.engineer@test.com',
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

  Future<String> seedEngineerRequestWithQuote() async {
    final requestId = await quoteService.submitQuoteRequest(
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
      submitStatus: QuoteRequestStatus.sent,
      contractorOrgId: orgId,
    );
    MockStore.instance.supplierQuotes.add(
      SupplierQuote(
        id: 'quote-1',
        quoteRequestId: requestId,
        supplierId: supplierId,
        supplierName: 'ספק QA',
        supplierType: UserType.commercialSupplier.value,
        deliveryTime: '2 ימים',
        totalPrice: 100,
        status: SupplierQuoteStatus.sent,
        createdAt: DateTime(2026),
        items: const [
          SupplierQuoteItem(
            id: 'qi-1',
            supplierQuoteId: 'quote-1',
            productId: 'manual-1',
            productName: 'בלוק 20',
            requestedQuantity: 2,
            unitPrice: 50,
            totalItemPrice: 100,
          ),
        ],
      ),
    );
    return requestId;
  }

  test('procurement approves quote on engineer-created RFQ', () async {
    final requestId = await seedEngineerRequestWithQuote();

    await quoteService.approveCustomerQuote(
      quoteId: 'quote-1',
      requestId: requestId,
      actorUid: procurementId,
      memberships: [procurementMembership()],
      orgId: orgId,
    );

    final request = MockStore.instance.getRequest(requestId)!;
    final quote = MockStore.instance.supplierQuotes.first;
    expect(request.customerId, engineerId);
    expect(request.approvedQuoteId, 'quote-1');
    expect(quote.status, SupplierQuoteStatus.approved);
  });

  test('engineer cannot approve quote on own RFQ', () async {
    final requestId = await seedEngineerRequestWithQuote();

    expect(
      () => quoteService.approveCustomerQuote(
        quoteId: 'quote-1',
        requestId: requestId,
        actorUid: engineerId,
        memberships: [engineerMembership()],
        orgId: orgId,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('second approval is blocked', () async {
    final requestId = await seedEngineerRequestWithQuote();
    MockStore.instance.supplierQuotes.add(
      SupplierQuote(
        id: 'quote-2',
        quoteRequestId: requestId,
        supplierId: 'sup-2',
        supplierName: 'ספק 2',
        supplierType: UserType.commercialSupplier.value,
        deliveryTime: '3 ימים',
        totalPrice: 90,
        status: SupplierQuoteStatus.sent,
        createdAt: DateTime(2026),
      ),
    );

    await quoteService.approveCustomerQuote(
      quoteId: 'quote-1',
      requestId: requestId,
      actorUid: procurementId,
      memberships: [procurementMembership()],
      orgId: orgId,
    );

    expect(
      () => quoteService.approveCustomerQuote(
        quoteId: 'quote-2',
        requestId: requestId,
        actorUid: procurementId,
        memberships: [procurementMembership()],
        orgId: orgId,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
