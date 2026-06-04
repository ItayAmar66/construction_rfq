import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stable catalog RFQ analytics event names.
abstract final class CatalogRfqEventNames {
  static const selectorOpened = 'catalog_selector_opened';
  static const catalogItemSelected = 'catalog_item_selected';
  static const manualItemAdded = 'manual_item_added';
  static const supplierExactQuote = 'supplier_exact_quote';
  static const supplierAlternativeQuote = 'supplier_alternative_quote';
  static const approvalWithAlternatives = 'approval_with_alternatives';
}

/// Lightweight analytics hook — swap for Firebase/Amplitude later.
abstract class CatalogRfqAnalytics {
  void track(String name, [Map<String, Object?>? params]);
}

/// Default no-op implementation (safe in production until wired).
class NoOpCatalogRfqAnalytics implements CatalogRfqAnalytics {
  const NoOpCatalogRfqAnalytics();

  @override
  void track(String name, [Map<String, Object?>? params]) {}
}

/// Debug logging implementation.
class DebugCatalogRfqAnalytics implements CatalogRfqAnalytics {
  const DebugCatalogRfqAnalytics();

  @override
  void track(String name, [Map<String, Object?>? params]) {
    if (kDebugMode) {
      debugPrint('[catalog-rfq] $name ${params ?? {}}');
    }
  }
}

final catalogRfqAnalyticsProvider = Provider<CatalogRfqAnalytics>(
  (ref) => kDebugMode
      ? const DebugCatalogRfqAnalytics()
      : const NoOpCatalogRfqAnalytics(),
);
