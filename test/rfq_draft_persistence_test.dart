import 'package:construction_rfq/providers/rfq_draft_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restores a previously-saved draft for the same scope after restart', () async {
    final prefs = await SharedPreferences.getInstance();

    final first = RfqDraftNotifier();
    first.attachScope(prefs: prefs, uid: 'uid-1');
    first.addManualItem(productName: 'ברגים', category: 'כללי', unitType: 'יח\'');
    expect(first.state, hasLength(1));

    // Simulate an app restart: fresh notifier, same prefs instance.
    final second = RfqDraftNotifier();
    second.attachScope(prefs: prefs, uid: 'uid-1');
    expect(second.state, hasLength(1));
    expect(second.state.first.productName, 'ברגים');
  });

  test('isolates drafts between different users on the same device', () async {
    final prefs = await SharedPreferences.getInstance();

    final userA = RfqDraftNotifier();
    userA.attachScope(prefs: prefs, uid: 'uid-a');
    userA.addManualItem(productName: 'מוצר-א', category: 'כללי', unitType: 'יח\'');

    final userB = RfqDraftNotifier();
    userB.attachScope(prefs: prefs, uid: 'uid-b');
    expect(userB.state, isEmpty);
  });

  test('isolates drafts between different orgs for the same user', () async {
    final prefs = await SharedPreferences.getInstance();

    final orgOne = RfqDraftNotifier();
    orgOne.attachScope(prefs: prefs, uid: 'uid-1', orgId: 'org-1');
    orgOne.addManualItem(productName: 'מוצר-1', category: 'כללי', unitType: 'יח\'');

    final orgTwo = RfqDraftNotifier();
    orgTwo.attachScope(prefs: prefs, uid: 'uid-1', orgId: 'org-2');
    expect(orgTwo.state, isEmpty);
  });

  test('explicit discard (clear) removes the persisted draft', () async {
    final prefs = await SharedPreferences.getInstance();

    final notifier = RfqDraftNotifier();
    notifier.attachScope(prefs: prefs, uid: 'uid-1');
    notifier.addManualItem(productName: 'פריט', category: 'כללי', unitType: 'יח\'');
    expect(prefs.getString('rfq_draft_v1:uid-1'), isNotNull);

    notifier.clear();
    expect(prefs.getString('rfq_draft_v1:uid-1'), isNull);

    final restored = RfqDraftNotifier();
    restored.attachScope(prefs: prefs, uid: 'uid-1');
    expect(restored.state, isEmpty);
  });

  test('successful submission (clear) leaves no draft behind on next restore', () async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = RfqDraftNotifier();
    notifier.attachScope(prefs: prefs, uid: 'uid-1');
    notifier.addManualItem(productName: 'פריט', category: 'כללי', unitType: 'יח\'');
    notifier.clear(); // what cart_screen calls after a confirmed backend success

    final restored = RfqDraftNotifier();
    restored.attachScope(prefs: prefs, uid: 'uid-1');
    expect(restored.state, isEmpty);
  });

  test('a failed submission preserves the draft (no clear() called)', () async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = RfqDraftNotifier();
    notifier.attachScope(prefs: prefs, uid: 'uid-1');
    notifier.addManualItem(productName: 'פריט', category: 'כללי', unitType: 'יח\'');
    // Simulated failed submit: cart_screen never calls clear() on error.
    expect(notifier.state, hasLength(1));

    final restored = RfqDraftNotifier();
    restored.attachScope(prefs: prefs, uid: 'uid-1');
    expect(restored.state, hasLength(1));
  });

  test('clientOperationId is stable across mutations and rotates on clear', () async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = RfqDraftNotifier();
    notifier.attachScope(prefs: prefs, uid: 'uid-1');
    final firstId = notifier.clientOperationId;

    notifier.addManualItem(productName: 'א', category: 'כללי', unitType: 'יח\'');
    notifier.addManualItem(productName: 'ב', category: 'כללי', unitType: 'יח\'');
    // Same idempotency key across retries/double taps of the same draft.
    expect(notifier.clientOperationId, firstId);

    notifier.clear();
    expect(notifier.clientOperationId, isNot(firstId));
  });

  test('clientOperationId survives an app restart (restore reloads it)', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = RfqDraftNotifier();
    first.attachScope(prefs: prefs, uid: 'uid-1');
    first.addManualItem(productName: 'פריט', category: 'כללי', unitType: 'יח\'');
    final savedId = first.clientOperationId;

    final second = RfqDraftNotifier();
    second.attachScope(prefs: prefs, uid: 'uid-1');
    expect(second.clientOperationId, savedId);
  });

  test('a corrupted local draft is discarded rather than crashing restore', () async {
    SharedPreferences.setMockInitialValues({
      'rfq_draft_v1:uid-1': 'not valid json {{{',
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = RfqDraftNotifier();
    expect(
      () => notifier.attachScope(prefs: prefs, uid: 'uid-1'),
      returnsNormally,
    );
    expect(notifier.state, isEmpty);
  });
}
