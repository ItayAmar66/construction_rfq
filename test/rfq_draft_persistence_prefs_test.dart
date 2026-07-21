import 'package:construction_rfq/models/catalog/catalog_rfq_line_draft.dart';
import 'package:construction_rfq/providers/providers.dart';
import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RfqDraftNotifier local persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('draft survives a fresh ProviderContainer (simulated app restart)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      container1.read(rfqDraftProvider.notifier).addCatalogDraft(
            const CatalogRfqLineDraft(
              variantId: 'v1',
              productId: '11',
              categoryId: '7',
              categoryPath: 'דבקים › חיפוי',
              displayName: 'דבק פיקס — לבן',
              sku: 'FX-1',
              unitType: 'שק',
              quantity: 3,
            ),
          );
      expect(container1.read(rfqDraftProvider), hasLength(1));
      container1.dispose();

      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      final restored = container2.read(rfqDraftProvider);
      expect(restored, hasLength(1));
      expect(restored.first.variantId, 'v1');
      expect(restored.first.quantity, 3);
      expect(restored.first.isCatalogMatched, isTrue);
    });

    test('clearing the draft removes it from local storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).addManualItem(
            productName: 'בלוק 20',
            category: 'בלוקים',
            unitType: 'יחידה',
          );
      expect(prefs.getString(rfqDraftPrefsKey), isNotNull);

      container.read(rfqDraftProvider.notifier).clear();
      expect(prefs.getString(rfqDraftPrefsKey), isNull);
    });

    test('without an overridden SharedPreferences, draft still works in-memory',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(rfqDraftProvider.notifier).addManualItem(
            productName: 'בלוק 20',
            category: 'בלוקים',
            unitType: 'יחידה',
          );

      expect(container.read(rfqDraftProvider), hasLength(1));
    });
  });
}
