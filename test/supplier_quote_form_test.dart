import 'package:construction_rfq/widgets/quote_financial_form_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  testWidgets('QuoteFinancialFormSection notifies after first frame', (tester) async {
    QuoteFinancialFormValues? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteFinancialFormSection(
            lineSubtotal: 100,
            onChanged: (values) => latest = values,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(latest, isNotNull);
    expect(latest!.breakdown.subtotal, 100);
  });
}
