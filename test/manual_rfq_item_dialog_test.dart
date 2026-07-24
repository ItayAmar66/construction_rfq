import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/widgets/manual_rfq_item_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a host with a button that opens [ManualRfqItemDialog] and records the
/// result, then opens the dialog. Returns a getter pair for the outcome.
Future<_DialogHandle> _openDialog(WidgetTester tester) async {
  ManualRfqItemResult? result;
  var completed = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ManualRfqItemDialog.show(context);
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

  return _DialogHandle(
    result: () => result,
    completed: () => completed,
  );
}

class _DialogHandle {
  _DialogHandle({required this.result, required this.completed});
  final ManualRfqItemResult? Function() result;
  final bool Function() completed;
}

Finder get _submitButton => find.text(HebrewStrings.addRfqItem);
Finder get _nameField => find.byType(TextFormField).first;

void main() {
  testWidgets('blocks submit and shows an error when the name is empty',
      (tester) async {
    final handle = await _openDialog(tester);

    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    // Validation error is shown and the dialog stays open (not popped).
    expect(find.text('שדה חובה'), findsOneWidget);
    expect(find.text(HebrewStrings.addManualRfqItem), findsOneWidget);
    expect(handle.completed(), isFalse);
  });

  testWidgets('returns a trimmed result with null notes on valid submit',
      (tester) async {
    final handle = await _openDialog(tester);

    await tester.enterText(_nameField, '  מלט אפור  ');
    await tester.tap(_submitButton);
    await tester.pumpAndSettle();

    expect(handle.completed(), isTrue);
    final result = handle.result();
    expect(result, isNotNull);
    expect(result!.productName, 'מלט אפור'); // trimmed
    expect(result.quantity, 1);
    expect(result.notes, isNull); // empty notes collapse to null
  });

  testWidgets('quantity stepper is floored at 1 and increments', (tester) async {
    await _openDialog(tester);

    // At quantity 1 the decrement control is disabled.
    final decrementAtOne = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
    );
    expect(decrementAtOne.onPressed, isNull);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.add_circle_outline),
    );
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    final decrementAtTwo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
    );
    expect(decrementAtTwo.onPressed, isNotNull);
  });

  testWidgets('cancel returns null', (tester) async {
    final handle = await _openDialog(tester);

    await tester.tap(find.text(HebrewStrings.cancel));
    await tester.pumpAndSettle();

    expect(handle.completed(), isTrue);
    expect(handle.result(), isNull);
  });
}
