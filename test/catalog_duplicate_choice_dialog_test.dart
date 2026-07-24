import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/widgets/catalog_duplicate_choice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens [CatalogDuplicateChoiceDialog] for [displayName] and records the
/// choice the user makes.
Future<CatalogDuplicateChoice? Function()> _openDialog(
  WidgetTester tester, {
  String displayName = 'מלט אפור',
}) async {
  CatalogDuplicateChoice? choice;
  var completed = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              choice = await CatalogDuplicateChoiceDialog.show(
                context,
                displayName: displayName,
              );
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(completed, isFalse); // dialog is open, awaiting a choice
  return () => choice;
}

void main() {
  testWidgets('renders the duplicate item name', (tester) async {
    await _openDialog(tester, displayName: 'ברזל 12 מ"מ');
    expect(find.textContaining('ברזל 12 מ"מ'), findsOneWidget);
  });

  testWidgets('"add quantity" resolves to mergeQuantity', (tester) async {
    final choice = await _openDialog(tester);

    await tester.tap(find.text('הוסף כמות'));
    await tester.pumpAndSettle();

    expect(choice(), CatalogDuplicateChoice.mergeQuantity);
  });

  testWidgets('"separate line" resolves to separateLine', (tester) async {
    final choice = await _openDialog(tester);

    await tester.tap(find.text('שורה נפרדת'));
    await tester.pumpAndSettle();

    expect(choice(), CatalogDuplicateChoice.separateLine);
  });

  testWidgets('cancel resolves to null', (tester) async {
    final choice = await _openDialog(tester);

    await tester.tap(find.text(HebrewStrings.cancel));
    await tester.pumpAndSettle();

    expect(choice(), isNull);
  });
}
