import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmptyState shows optional action button', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            message: 'Empty',
            actionLabel: HebrewStrings.retryAction,
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text(HebrewStrings.retryAction), findsOneWidget);
    await tester.tap(find.text(HebrewStrings.retryAction));
    expect(tapped, isTrue);
  });
}
