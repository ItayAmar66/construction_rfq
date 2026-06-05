import 'package:construction_rfq/config/app_mode.dart';
import 'package:construction_rfq/data/enterprise_demo_scenario.dart';
import 'package:construction_rfq/models/quote_status.dart';
import 'package:construction_rfq/services/mock_store.dart';
import 'package:construction_rfq/utils/quote_comparison_matrix.dart';
import 'package:construction_rfq/utils/supplier_quote_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppMode.isDemoMode = true;
    MockStore.instance.init();
    MockStore.instance.quoteRequests.clear();
    MockStore.instance.supplierQuotes.clear();
  });

  tearDown(() {
    AppMode.isDemoMode = false;
  });

    test('seeds compare scenario with catalog, manual, exact and alternative quotes',
      () {
    EnterpriseDemoScenario.seedIfNeeded(MockStore.instance);

    expect(EnterpriseDemoScenario.customerCompany, contains('בנייה'));

    final active = MockStore.instance.getRequest(
      EnterpriseDemoScenario.activeRequestId,
    );
    expect(active, isNotNull);
    expect(active!.status, QuoteRequestStatus.sent);
    expect(active.notes, contains(EnterpriseDemoScenario.projectSite));

    final compare = MockStore.instance.getRequest(
      EnterpriseDemoScenario.compareRequestId,
    );
    expect(compare, isNotNull);
    expect(compare!.status, QuoteRequestStatus.quotesReceived);
    expect(compare.items.where((i) => i.isCatalogMatched), hasLength(1));
    expect(compare.items.where((i) => !i.isCatalogMatched), hasLength(1));

    final quotes = MockStore.instance.supplierQuotes
        .where((q) => q.quoteRequestId == compare.id)
        .toList();
    expect(quotes, hasLength(2));
    expect(quotes.any((q) => q.items.any((i) => i.isExactMatch)), isTrue);
    expect(quotes.any((q) => q.items.any((i) => i.isAlternative)), isTrue);

    final matrix = buildQuoteComparisonMatrix(
      requestItems: compare.items,
      quotes: quotes,
    );
    expect(matrix.columnCount, 2);
    expect(matrix.cells[EnterpriseDemoScenario.altQuoteId]![EnterpriseDemoScenario.manualLineId]!.status,
        QuoteMatrixCellStatus.missing);
  });

  test('seeds fulfilled shipped order for audit walkthrough', () {
    EnterpriseDemoScenario.seedIfNeeded(MockStore.instance);

    final fulfilled = MockStore.instance.getRequest(
      EnterpriseDemoScenario.fulfilledRequestId,
    );
    expect(fulfilled, isNotNull);
    expect(fulfilled!.status, QuoteRequestStatus.shipped);
    expect(fulfilled.approvedQuoteId, EnterpriseDemoScenario.approvedQuoteId);

    final approved = MockStore.instance.supplierQuotes
        .firstWhere((q) => q.id == EnterpriseDemoScenario.approvedQuoteId);
    expect(approved.status, SupplierQuoteStatus.shipped);
  });

  test('seed is idempotent', () {
    EnterpriseDemoScenario.seedIfNeeded(MockStore.instance);
    final count = MockStore.instance.quoteRequests.length;
    EnterpriseDemoScenario.seedIfNeeded(MockStore.instance);
    expect(MockStore.instance.quoteRequests.length, count);
  });
}
