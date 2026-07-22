import 'package:construction_rfq/utils/app_theme.dart';
import 'package:construction_rfq/widgets/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('PrimaryButton renders label and handles tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(PrimaryButton(label: 'שמור', onPressed: () => tapped = true)),
    );

    expect(find.text('שמור'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton shows spinner and disables tap while loading',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(PrimaryButton(
        label: 'שמור',
        isLoading: true,
        onPressed: () => tapped = true,
      )),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(tapped, isFalse);
  });

  testWidgets('SecondaryButton renders label and handles tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(SecondaryButton(label: 'ביטול', onPressed: () => tapped = true)),
    );

    expect(find.text('ביטול'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppCard renders child and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(AppCard(
        onTap: () => tapped = true,
        child: const Text('תוכן'),
      )),
    );

    expect(find.text('תוכן'), findsOneWidget);
    await tester.tap(find.byType(AppCard));
    expect(tapped, isTrue);
  });

  testWidgets('SearchField shows hint and reports changes', (tester) async {
    String? lastValue;
    await tester.pumpWidget(
      _wrap(SearchField(hintText: 'חפש', onChanged: (v) => lastValue = v)),
    );

    expect(find.text('חפש'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'מלט');
    expect(lastValue, 'מלט');
  });

  testWidgets('MetricCard/SectionHeader/LoadingState aliases build',
      (tester) async {
    await tester.pumpWidget(_wrap(Column(
      children: const [
        MetricCard(label: 'סה"כ', value: '12', icon: Icons.inventory_2),
        SectionHeader(title: 'כותרת', icon: Icons.dashboard_outlined),
        SizedBox(height: 100, child: LoadingState()),
      ],
    )));

    expect(find.byType(MetricCard), findsOneWidget);
    expect(find.text('כותרת'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
