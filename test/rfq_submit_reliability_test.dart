import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/repositories/request_repository.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.isDemoMode = true;
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

  test('each submit creates a distinct customer request', () async {
    final repo = RequestRepository();
    final customer = AppUser(
      id: 'cust-submit',
      fullName: 'Submit Customer',
      email: 'submit@test.com',
      phone: '0505555555',
      userType: UserType.commercialCustomer,
      city: 'תל אביב',
      createdAt: DateTime(2024, 1, 1),
    );

    const line = QuoteRequestItem(
      id: 'line-1',
      quoteRequestId: '',
      productId: 'p1',
      productName: 'בדיקה',
      category: 'כללי',
      unitType: 'יחידה',
      quantity: 1,
    );
    expect(line.productName, 'בדיקה');

    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      ids.add(
        await repo.submitQuoteRequest(
          customer: customer,
          requestItems: [
            QuoteRequestItem(
              id: 'line-$i',
              quoteRequestId: '',
              productId: 'p$i',
              productName: 'בדיקה $i',
              category: 'כללי',
              unitType: 'יחידה',
              quantity: 1,
            ),
          ],
        ),
      );
    }

    expect(ids.toSet(), hasLength(5));
    final requests = await repo.watchCustomerRequests(customer.id).first;
    expect(requests, hasLength(5));
  });
}
