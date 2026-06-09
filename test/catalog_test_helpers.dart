import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Select a category in [CatalogSelectorScreen] via chip or searchable picker.
Future<void> selectCatalogCategory(WidgetTester tester, String name) async {
  final chip = find.widgetWithText(FilterChip, name);
  if (chip.evaluate().isNotEmpty) {
    await tester.tap(chip);
  } else {
    await tester.tap(find.text(HebrewStrings.catalogAllCategoriesPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
  }
  await tester.pumpAndSettle();
}

void expectCategoryChipSelected(
  WidgetTester tester,
  String name, {
  required bool selected,
}) {
  final chipFinder = find.widgetWithText(FilterChip, name);
  expect(chipFinder, findsOneWidget);
  expect(tester.widget<FilterChip>(chipFinder).selected, selected);
}
