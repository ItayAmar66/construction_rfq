import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../models/catalog/catalog_rfq_line_draft.dart';
import '../models/quote_request_item.dart';

const _prefsKeyPrefix = 'rfq_draft_v1:';

/// Persists the active RFQ draft locally (SharedPreferences), scoped to the
/// signed-in user (+org, when known) so restarts/crashes don't lose an
/// in-progress request and one user's device session never leaks another's
/// draft. Call [attachScope] once a session (e.g. from the cart screen) as
/// soon as uid/orgId are known; every mutation after that write-throughs.
class RfqDraftNotifier extends StateNotifier<List<QuoteRequestItem>> {
  RfqDraftNotifier() : super([]);

  static const _uuid = Uuid();

  SharedPreferences? _prefs;
  String? _scopeKey;

  /// Stable per-draft id used as the Firestore write's idempotency key, so a
  /// retried/duplicated submit can be recognized instead of creating a
  /// second RFQ. Regenerated only when the draft is cleared.
  String clientOperationId = _uuid.v4();

  String? get _storageKey => _scopeKey == null ? null : '$_prefsKeyPrefix$_scopeKey';

  /// Binds this notifier to a user (+org) scope and restores any
  /// previously-saved draft for that exact scope. Safe to call more than
  /// once (e.g. on every screen mount) — a no-op after the first successful
  /// bind for the same scope, and never overwrites an already-populated
  /// in-memory draft from a different scope with stale data.
  void attachScope({
    required SharedPreferences prefs,
    required String uid,
    String? orgId,
  }) {
    final scopeKey = orgId == null || orgId.isEmpty ? uid : '$uid:$orgId';
    if (_prefs != null && _scopeKey == scopeKey) return;
    _prefs = prefs;
    _scopeKey = scopeKey;
    if (state.isEmpty) {
      _restore();
    }
  }

  void _restore() {
    final key = _storageKey;
    final prefs = _prefs;
    if (key == null || prefs == null) return;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['items'] is! List) return;
      final items = (decoded['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => QuoteRequestItem.fromMap(
                m['id']?.toString() ?? _uuid.v4(),
                m,
              ))
          .toList();
      if (decoded['clientOperationId'] is String) {
        clientOperationId = decoded['clientOperationId'] as String;
      }
      state = items;
    } catch (_) {
      // Corrupted local draft — start clean rather than crash the screen.
      prefs.remove(key);
    }
  }

  void _persist() {
    final key = _storageKey;
    final prefs = _prefs;
    if (key == null || prefs == null) return;
    if (state.isEmpty) {
      prefs.remove(key);
      return;
    }
    prefs.setString(
      key,
      jsonEncode({
        'clientOperationId': clientOperationId,
        'items': state.map((item) => {'id': item.id, ...item.toMap()}).toList(),
      }),
    );
  }

  void _setState(List<QuoteRequestItem> next) {
    state = next;
    _persist();
  }

  void addCatalogDraft(
    CatalogRfqLineDraft draft, {
    bool forceSeparateLine = false,
  }) {
    if (!forceSeparateLine && draft.variantId.isNotEmpty) {
      final index = state.indexWhere(
        (item) => item.isCatalogMatched && item.variantId == draft.variantId,
      );
      if (index >= 0) {
        final existing = state[index];
        updateQuantity(existing.id, existing.quantity + draft.quantity);
        return;
      }
    }

    _setState([
      ...state,
      QuoteRequestItem.fromCatalogDraft(
        draft,
        lineId: _uuid.v4(),
      ),
    ]);
  }

  int? findCatalogVariantLineIndex(String variantId) {
    if (variantId.isEmpty) return null;
    return state.indexWhere(
      (item) => item.isCatalogMatched && item.variantId == variantId,
    );
  }

  int catalogVariantQuantity(String variantId) {
    final index = findCatalogVariantLineIndex(variantId);
    if (index == null) return 0;
    return state[index].quantity;
  }

  /// Quick add merges quantity on the same catalog variant line.
  void quickAddCatalogVariant(CatalogRfqLineDraft draft) {
    addCatalogDraft(draft);
  }

  /// Decrease catalog variant quantity by 1; removes line at zero.
  void decrementCatalogVariant(String variantId) {
    final index = findCatalogVariantLineIndex(variantId);
    if (index == null) return;
    final item = state[index];
    updateQuantity(item.id, item.quantity - 1);
  }

  void addManualItem({
    required String productName,
    required String category,
    required String unitType,
    int quantity = 1,
    String? notes,
    String? productId,
  }) {
    _setState([
      ...state,
      QuoteRequestItem(
        id: _uuid.v4(),
        quoteRequestId: '',
        productId: productId ?? 'manual_${_uuid.v4()}',
        productName: productName,
        category: category,
        unitType: unitType,
        quantity: quantity,
        notes: notes,
        isCatalogMatched: false,
      ),
    ]);
  }

  void importLegacyCart(List<CartItem> cartItems) {
    if (cartItems.isEmpty) return;

    var next = [...state];
    for (final cartItem in cartItems) {
      final index = next.indexWhere(
        (item) =>
            !item.isCatalogMatched && item.productId == cartItem.product.id,
      );
      if (index >= 0) {
        next[index] = next[index].copyWith(quantity: cartItem.quantity);
      } else {
        next.add(
          QuoteRequestItem.fromLegacyProduct(
            product: cartItem.product,
            quantity: cartItem.quantity,
            lineId: _uuid.v4(),
            notes: cartItem.notes,
          ),
        );
      }
    }
    _setState(next);
  }

  void updateQuantity(String lineId, int quantity) {
    if (quantity <= 0) {
      removeLine(lineId);
      return;
    }
    _setState([
      for (final item in state)
        if (item.id == lineId) item.copyWith(quantity: quantity) else item,
    ]);
  }

  void updateLineNotes(String lineId, String notes) {
    final trimmed = notes.trim();
    _setState([
      for (final item in state)
        if (item.id == lineId)
          item.copyWith(
            notes: trimmed.isEmpty ? null : trimmed,
            updateNotes: true,
          )
        else
          item,
    ]);
  }

  void removeLine(String lineId) {
    _setState(state.where((item) => item.id != lineId).toList());
  }

  void replaceAll(List<QuoteRequestItem> items) => _setState(List.of(items));

  /// Clears the draft (successful submit or explicit discard) and rotates
  /// the idempotency key so a NEW draft never reuses a completed submit's id.
  void clear() {
    clientOperationId = _uuid.v4();
    _setState([]);
  }

  int get totalQuantity =>
      state.fold(0, (sum, item) => sum + item.quantity);
}

final rfqDraftProvider =
    StateNotifierProvider<RfqDraftNotifier, List<QuoteRequestItem>>(
  (ref) => RfqDraftNotifier(),
);

final rfqDraftCountProvider = Provider<int>((ref) {
  final draft = ref.watch(rfqDraftProvider);
  return draft.fold(0, (sum, item) => sum + item.quantity);
});

/// Variant id → total quantity in RFQ draft (for catalog card badges).
final catalogDraftQuantityByVariantProvider = Provider<Map<String, int>>((ref) {
  final draft = ref.watch(rfqDraftProvider);
  final map = <String, int>{};
  for (final item in draft) {
    final variantId = item.variantId;
    if (!item.isCatalogMatched || variantId == null || variantId.isEmpty) {
      continue;
    }
    map[variantId] = (map[variantId] ?? 0) + item.quantity;
  }
  return map;
});
