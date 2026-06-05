import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/repositories/request_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:flutter_test/flutter_test.dart';

QuoteRequestItem _sampleLine() {
  return const QuoteRequestItem(
    id: 'req-line-1',
    quoteRequestId: '',
    productId: 'prod-1',
    productName: 'בלוק 20',
    category: 'בלוקים',
    unitType: 'יחידה',
    quantity: 5,
  );
}

AppUser _customer() {
  return AppUser(
    id: 'cust-repo-test',
    fullName: 'Repo Test Customer',
    email: 'repo@test.com',
    phone: '0503333333',
    userType: UserType.commercialCustomer,
    city: 'תל אביב',
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  late RequestRepository repository;

  setUp(() {
    AppMode.isDemoMode = true;
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
    repository = RequestRepository();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  group('RequestRepository demo mode', () {
    test('submitQuoteRequest persists request with items', () async {
      final requestId = await repository.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_sampleLine()],
        notes: 'בדיקה',
      );

      expect(requestId, isNotEmpty);

      final stored = MockStore.instance.getRequest(requestId);
      expect(stored, isNotNull);
      expect(stored!.customerId, _customer().id);
      expect(stored.notes, 'בדיקה');
      expect(stored.items, hasLength(1));
      expect(stored.items.first.productName, 'בלוק 20');
      expect(stored.items.first.quantity, 5);
    });

    test('getRequest returns stored request', () async {
      final requestId = await repository.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_sampleLine()],
      );

      final request = await repository.getRequest(requestId);

      expect(request, isNotNull);
      expect(request!.id, requestId);
      expect(request.customerId, _customer().id);
    });

    test('getRequestItems returns embedded line items', () async {
      final requestId = await repository.submitQuoteRequest(
        customer: _customer(),
        requestItems: [_sampleLine()],
      );

      final items = await repository.getRequestItems(requestId);

      expect(items, hasLength(1));
      expect(items.first.productId, 'prod-1');
      expect(items.first.quoteRequestId, requestId);
    });
  });
}
