import 'package:construction_rfq/widgets/procurement_panel.dart';
import 'package:construction_rfq/widgets/rfq_builder_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProcurementScreenIntro renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProcurementScreenIntro(
            title: 'Title',
            subtitle: 'Subtitle',
          ),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Subtitle'), findsOneWidget);
  });

  testWidgets('RfqDraftSectionHeader shows optional subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RfqDraftSectionHeader(
            title: 'Section',
            subtitle: 'Details',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      ),
    );

    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });
}
