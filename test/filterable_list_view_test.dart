import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/utils/hebrew_strings.dart';
import 'package:construction_rfq/utils/request_status_group.dart';
import 'package:construction_rfq/widgets/filterable_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Item {
  const _Item(this.name, this.tag, this.date);
  final String name;
  final String tag;
  final DateTime date;
}

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

FilterableListView<_Item> _buildList(List<_Item> items) {
  return FilterableListView<_Item>(
    items: items,
    dateFor: (i) => i.date,
    searchTextFor: (i) => i.name,
    filters: [
      ListFilter<_Item>.all(),
      ListFilter<_Item>(label: 'פתוחות', test: (i) => i.tag == 'open'),
      ListFilter<_Item>(label: 'הושלמו', test: (i) => i.tag == 'done'),
    ],
    itemBuilder: (context, i) => Text(i.name),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
  });

  final items = [
    _Item('אלפא ברזל', 'open', DateTime(2026, 7, 20)),
    _Item('בטא מלט', 'done', DateTime(2026, 7, 20)),
    _Item('גמא צינורות', 'open', DateTime(2026, 7, 19)),
  ];

  group('FilterableListView', () {
    testWidgets('shows all items initially', (tester) async {
      await tester.pumpWidget(_host(_buildList(items)));
      await tester.pumpAndSettle();

      expect(find.text('אלפא ברזל'), findsOneWidget);
      expect(find.text('בטא מלט'), findsOneWidget);
      expect(find.text('גמא צינורות'), findsOneWidget);
    });

    testWidgets('filter pill narrows the list by predicate', (tester) async {
      await tester.pumpWidget(_host(_buildList(items)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('הושלמו'));
      await tester.pumpAndSettle();

      expect(find.text('בטא מלט'), findsOneWidget);
      expect(find.text('אלפא ברזל'), findsNothing);
      expect(find.text('גמא צינורות'), findsNothing);
    });

    testWidgets('search narrows the list by text', (tester) async {
      await tester.pumpWidget(_host(_buildList(items)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'גמא');
      await tester.pumpAndSettle();

      expect(find.text('גמא צינורות'), findsOneWidget);
      expect(find.text('אלפא ברזל'), findsNothing);
      expect(find.text('בטא מלט'), findsNothing);
    });

    testWidgets('no-results state appears and clears', (tester) async {
      await tester.pumpWidget(_host(_buildList(items)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'לא-קיים-כלל');
      await tester.pumpAndSettle();

      expect(find.text(HebrewStrings.noMatchingResults), findsOneWidget);
      expect(find.text('אלפא ברזל'), findsNothing);

      await tester.tap(find.text(HebrewStrings.clearFilters));
      await tester.pumpAndSettle();

      expect(find.text('אלפא ברזל'), findsOneWidget);
      expect(find.text('בטא מלט'), findsOneWidget);
    });

    testWidgets('hides the search field when searchTextFor is null',
        (tester) async {
      await tester.pumpWidget(_host(
        FilterableListView<_Item>(
          items: items,
          dateFor: (i) => i.date,
          filters: [
            ListFilter<_Item>.all(),
            ListFilter<_Item>(label: 'הושלמו', test: (i) => i.tag == 'done'),
          ],
          itemBuilder: (context, i) => Text(i.name),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);

      // Filters still work without search.
      await tester.tap(find.text('הושלמו'));
      await tester.pumpAndSettle();
      expect(find.text('בטא מלט'), findsOneWidget);
      expect(find.text('אלפא ברזל'), findsNothing);
    });

    testWidgets('search combines with the active filter', (tester) async {
      await tester.pumpWidget(_host(_buildList(items)));
      await tester.pumpAndSettle();

      // Filter to open items, then search a term that only matches a done item.
      await tester.tap(find.text('פתוחות'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'בטא');
      await tester.pumpAndSettle();

      expect(find.text(HebrewStrings.noMatchingResults), findsOneWidget);
    });
  });

  group('requestStatusGroup', () {
    test('buckets every status exhaustively', () {
      for (final s in QuoteRequestStatus.values) {
        // Must not throw and must return a non-null group for every status.
        expect(requestStatusGroup(s), isA<RequestStatusGroup>());
      }
    });

    test('maps representative statuses to the expected bucket', () {
      expect(requestStatusGroup(QuoteRequestStatus.draft),
          RequestStatusGroup.drafts);
      expect(requestStatusGroup(QuoteRequestStatus.procurementRejected),
          RequestStatusGroup.drafts);
      expect(
          requestStatusGroup(QuoteRequestStatus.sent), RequestStatusGroup.open);
      expect(requestStatusGroup(QuoteRequestStatus.quotesReceived),
          RequestStatusGroup.open);
      expect(requestStatusGroup(QuoteRequestStatus.ordered),
          RequestStatusGroup.inProgress);
      expect(requestStatusGroup(QuoteRequestStatus.shipped),
          RequestStatusGroup.inProgress);
      expect(requestStatusGroup(QuoteRequestStatus.completed),
          RequestStatusGroup.done);
      expect(requestStatusGroup(QuoteRequestStatus.cancelled),
          RequestStatusGroup.done);
    });
  });
}
