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

  testWidgets('PrimaryButton.danger renders and taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(PrimaryButton.danger(label: 'מחק', onPressed: () => tapped = true)),
    );
    expect(find.text('מחק'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton.loading disables and shows spinner',
      (tester) async {
    await tester.pumpWidget(_wrap(const PrimaryButton.loading(label: 'טוען')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final b = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(b.onPressed, isNull);
  });

  testWidgets('PrimaryButton.icon and .tonal build', (tester) async {
    await tester.pumpWidget(_wrap(Column(children: const [
      PrimaryButton.icon(icon: Icons.add, label: 'הוסף'),
      PrimaryButton.tonal(label: 'רך'),
    ])));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('הוסף'), findsOneWidget);
    expect(find.text('רך'), findsOneWidget);
  });

  testWidgets('SecondaryButton.loading disables and shows spinner',
      (tester) async {
    await tester.pumpWidget(_wrap(const SecondaryButton.loading(label: 'טוען')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final b = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(b.onPressed, isNull);
  });

  testWidgets('TertiaryButton renders label and taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(TertiaryButton(label: 'דלג', onPressed: () => tapped = true)),
    );
    expect(find.text('דלג'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppCard variants build; interactive taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(Column(children: [
      AppCard.interactive(onTap: () => tapped = true, child: const Text('אינט')),
      const AppCard.gradient(
        gradient: AppTheme.gradientNavy,
        child: Text('גרד'),
      ),
      AppCard.border(
        border: Border.all(color: AppTheme.teal),
        child: const Text('גבול'),
      ),
      const AppCard.clip(child: Text('קליפ')),
      const AppCard.compact(child: Text('קומפקט')),
    ])));
    expect(find.text('גרד'), findsOneWidget);
    expect(find.text('קליפ'), findsOneWidget);
    expect(find.text('קומפקט'), findsOneWidget);
    await tester.tap(find.text('אינט'));
    expect(tapped, isTrue);
  });

  testWidgets('SearchField supports loading and onSubmitted', (tester) async {
    String? submitted;
    await tester.pumpWidget(_wrap(SearchField(
      hintText: 'חפש',
      loading: true,
      onSubmitted: (v) => submitted = v,
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'מלט');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'מלט');
  });

  testWidgets('AppTextField renders label and validates', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(_wrap(Form(
      key: formKey,
      child: AppTextField(
        label: 'שם',
        validator: (v) => (v == null || v.isEmpty) ? 'נדרש' : null,
      ),
    )));
    expect(find.text('שם'), findsOneWidget);
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('נדרש'), findsOneWidget);
  });

  testWidgets('StatusChip renders label', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusChip(label: 'סטטוס', foreground: AppTheme.navy)),
    );
    expect(find.text('סטטוס'), findsOneWidget);
  });
}
