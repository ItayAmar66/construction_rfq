import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/models/quote_request.dart';
import 'package:construction_rfq/models/quote_request_item.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/request_display_helpers.dart';
import 'package:construction_rfq/widgets/demo_mode_banner.dart';
import 'package:construction_rfq/widgets/demo_scenario_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestDisplayHelpers', () {
    const items = [
      QuoteRequestItem(
        id: 'l1',
        quoteRequestId: 'r1',
        productId: 'p1',
        productName: 'דבק פיקס',
        category: 'חיפוי',
        unitType: 'שק',
        quantity: 2,
      ),
      QuoteRequestItem(
        id: 'l2',
        quoteRequestId: 'r1',
        productId: 'p2',
        productName: 'בלוק 20',
        category: 'בלוקים',
        unitType: 'יחידה',
        quantity: 100,
      ),
    ];

    test('materialsSummary joins item names', () {
      expect(
        RequestDisplayHelpers.materialsSummary(items),
        'דבק פיקס, בלוק 20',
      );
    });

    test('customerRequestTitle prefers notes then materials', () {
      final withNotes = QuoteRequest(
        id: 'abc123xyz',
        customerId: 'c1',
        customerName: 'קבלן',
        customerPhone: '050',
        customerCity: 'תל אביב',
        customerType: 'private',
        status: QuoteRequestStatus.sent,
        notes: 'פרויקט מגדלים — קומה 3',
        createdAt: DateTime(2026, 1, 1),
        items: items,
      );
      expect(
        RequestDisplayHelpers.customerRequestTitle(withNotes),
        'פרויקט מגדלים — קומה 3',
      );

      final noNotes = withNotes.copyWith(notes: null);
      expect(
        RequestDisplayHelpers.customerRequestTitle(noNotes),
        isNot(contains('abc123')),
      );
    });
  });

  group('Product polish guardrails', () {
    test('user-facing Hebrew avoids cart/checkout wording', () {
      expect(HebrewStrings.rfqDraftTitle, isNot(contains('עגלה')));
      expect(HebrewStrings.materialRequest, 'בקשת חומרים');
      expect(HebrewStrings.addRfqItem, 'הוסף לבקשה');
      expect(HebrewStrings.submitRequest, 'שליחה לספקים');
      expect(HebrewStrings.emptyCart, HebrewStrings.emptyRfqDraft);
    });

    testWidgets('demo presentation hidden when demo mode off', (tester) async {
      AppMode.isDemoMode = false;
      addTearDown(() => AppMode.isDemoMode = false);

      expect(AppMode.showDemoPresentation, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DemoModeBanner(),
                DemoScenarioPanel(),
              ],
            ),
          ),
        ),
      );

      expect(find.text(HebrewStrings.demoModeBadge), findsNothing);
      expect(find.text(HebrewStrings.demoScenarioSection), findsNothing);
    });
  });
}

extension on QuoteRequest {
  QuoteRequest copyWith({String? notes}) {
    return QuoteRequest(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerCity: customerCity,
      customerType: customerType,
      status: status,
      notes: notes,
      createdAt: createdAt,
      items: items,
    );
  }
}
