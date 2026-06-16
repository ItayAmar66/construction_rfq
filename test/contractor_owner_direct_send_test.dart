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
import 'package:construction_rfq/utils/quote_financials.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late QuoteService quoteService;

  const orgId = 'org-small';
  const ownerId = 'small-owner';

  final owner = AppUser(
    id: ownerId,
    fullName: 'Small Contractor Owner',
    email: 'qa.contractor.small.owner@test.com',
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

  setUp(() {
    AppMode.enableDemoMode();
    MockStore.instance.init();
    quoteService = QuoteService();
    MockStore.instance.demoMemberships[ownerId] = Membership(
      uid: ownerId,
      orgId: orgId,
      orgType: OrganizationType.contractor,
      roles: const [EnterpriseRole.contractorCompanyOwner],
    );
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  test('small contractor owner creates and sends RFQ directly', () async {
    final requestId = await quoteService.submitQuoteRequest(
      customer: owner,
      requestItems: [line()],
      submitStatus: QuoteRequestStatus.sent,
      contractorOrgId: orgId,
      invitedSupplierOrgIds: const ['C5EKNz88l2UBn506FmFUzfyMhFi2'],
      invitedSupplierNames: const ['QA ספק קטן'],
    );

    final saved = MockStore.instance.getRequest(requestId)!;
    expect(saved.status, QuoteRequestStatus.sent);
    expect(saved.contractorOrgId, orgId);
    expect(saved.invitedSupplierOrgIds,
        contains('C5EKNz88l2UBn506FmFUzfyMhFi2'));
  });
}
