import 'package:construction_rfq/models/app_user.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/models/user_type.dart';
import 'package:construction_rfq/utils/supplier_targeting_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _supplier({List<String> categories = const [], String city = 'חיפה'}) {
  return AppUser(
    id: 'sup-1',
    fullName: 'Supplier',
    email: 's@test.com',
    phone: '050',
    userType: UserType.commercialSupplier,
    city: city,
    createdAt: DateTime(2024),
    supplierCategoryIds: categories,
    serviceAreas: [city],
  );
}

QuoteRequest _request({List<String> invited = const []}) {
  return QuoteRequest(
    id: 'req-1',
    customerId: 'c1',
    customerName: 'Customer',
    customerPhone: '050',
    customerCity: 'תל אביב',
    customerType: 'commercial',
    status: QuoteRequestStatus.sent,
    createdAt: DateTime(2024),
    invitedSupplierIds: invited,
  );
}

void main() {
  group('SupplierTargetingHelpers', () {
    test('category match helper detects overlap', () {
      final supplier = _supplier(categories: ['7', '9']);
      const items = [
        QuoteRequestItem(
          id: 'l1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Item',
          category: 'cat',
          unitType: 'יח',
          quantity: 1,
          categoryId: '7',
          isCatalogMatched: true,
        ),
      ];

      expect(
        SupplierTargetingHelpers.matchesRequestCategories(
          supplier: supplier,
          items: items,
        ),
        isTrue,
      );
    });

    test('invited supplier helper keeps broad fallback', () {
      final request = _request();
      expect(
        SupplierTargetingHelpers.isSupplierInvited(
          request: request,
          supplierId: 'any',
        ),
        isTrue,
      );
    });

    test('invited list restricts non-invited suppliers', () {
      final request = _request(invited: ['sup-2']);
      expect(
        SupplierTargetingHelpers.isSupplierInvited(
          request: request,
          supplierId: 'sup-1',
        ),
        isFalse,
      );
    });

    test('shouldShowToSupplier keeps broad fallback without invite list', () {
      final request = _request();
      expect(
        SupplierTargetingHelpers.shouldShowToSupplier(
          request: request,
          supplierId: 'any',
        ),
        isTrue,
      );
    });

    test('shouldShowToSupplier hides non-invited when invite list exists', () {
      final request = _request(invited: ['sup-2']);
      expect(
        SupplierTargetingHelpers.shouldShowToSupplier(
          request: request,
          supplierId: 'sup-1',
        ),
        isFalse,
      );
    });

    test('relevanceLabel shows category match text', () {
      final supplier = _supplier(categories: ['7']);
      final request = _request();
      const items = [
        QuoteRequestItem(
          id: 'l1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Item',
          category: 'c',
          unitType: 'יח',
          quantity: 1,
          categoryId: '7',
          isCatalogMatched: true,
        ),
      ];

      expect(
        SupplierTargetingHelpers.relevanceLabel(
          supplier: supplier,
          request: request,
          items: items,
        ),
        'מתאים לתחומי הספק',
      );
    });

    test('invited names restrict non-matching suppliers', () {
      final request = QuoteRequest(
        id: 'req-2',
        customerId: 'c1',
        customerName: 'Customer',
        customerPhone: '050',
        customerCity: 'תל אביב',
        customerType: 'commercial',
        status: QuoteRequestStatus.sent,
        createdAt: DateTime(2024),
        invitedSupplierNames: const [SupplierTargetingHelpers.qaStressSupplierA],
      );

      expect(
        SupplierTargetingHelpers.shouldShowToSupplier(
          request: request,
          supplierId: 'sup-1',
          supplierName: 'ספק עומס B — QA_STRESS_FLOW_002',
        ),
        isFalse,
      );
      expect(
        SupplierTargetingHelpers.shouldShowToSupplier(
          request: request,
          supplierId: 'sup-2',
          supplierName: SupplierTargetingHelpers.qaStressSupplierA,
        ),
        isTrue,
      );
    });

    test('relevanceLabel shows open rfq when no category overlap', () {
      final supplier = _supplier(categories: ['99']);
      final request = _request();
      const items = [
        QuoteRequestItem(
          id: 'l1',
          quoteRequestId: '',
          productId: 'p1',
          productName: 'Item',
          category: 'c',
          unitType: 'יח',
          quantity: 1,
          categoryId: '7',
          isCatalogMatched: true,
        ),
      ];

      expect(
        SupplierTargetingHelpers.relevanceLabel(
          supplier: supplier,
          request: request,
          items: items,
        ),
        'פתוח לכל הספקים',
      );
    });
  });
}
