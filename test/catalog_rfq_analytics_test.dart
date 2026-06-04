import 'package:construction_rfq/analytics/catalog_rfq_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCatalogRfqAnalytics implements CatalogRfqAnalytics {
  final events = <String>[];

  @override
  void track(String name, [Map<String, Object?>? params]) {
    events.add(name);
  }
}

void main() {
  group('CatalogRfqEventNames', () {
    test('event names are stable', () {
      expect(CatalogRfqEventNames.selectorOpened, 'catalog_selector_opened');
      expect(CatalogRfqEventNames.catalogItemSelected, 'catalog_item_selected');
      expect(CatalogRfqEventNames.manualItemAdded, 'manual_item_added');
      expect(CatalogRfqEventNames.supplierExactQuote, 'supplier_exact_quote');
      expect(
        CatalogRfqEventNames.supplierAlternativeQuote,
        'supplier_alternative_quote',
      );
      expect(
        CatalogRfqEventNames.approvalWithAlternatives,
        'approval_with_alternatives',
      );
    });
  });

  group('CatalogRfqAnalytics', () {
    test('no-op tracker accepts events without error', () {
      const analytics = NoOpCatalogRfqAnalytics();
      expect(() => analytics.track(CatalogRfqEventNames.selectorOpened), returnsNormally);
    });

    test('recording tracker captures flow events', () {
      final analytics = _RecordingCatalogRfqAnalytics();
      analytics.track(CatalogRfqEventNames.selectorOpened);
      analytics.track(CatalogRfqEventNames.catalogItemSelected);
      analytics.track(CatalogRfqEventNames.manualItemAdded);

      expect(analytics.events, [
        CatalogRfqEventNames.selectorOpened,
        CatalogRfqEventNames.catalogItemSelected,
        CatalogRfqEventNames.manualItemAdded,
      ]);
    });
  });
}
