import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../models/catalog/catalog_rfq_line_draft.dart';
import '../models/quote_request_item.dart';

class RfqDraftNotifier extends StateNotifier<List<QuoteRequestItem>> {
  RfqDraftNotifier() : super([]);

  static const _uuid = Uuid();

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

    state = [
      ...state,
      QuoteRequestItem.fromCatalogDraft(
        draft,
        lineId: _uuid.v4(),
      ),
    ];
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
    state = [
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
    ];
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
    state = next;
  }

  void updateQuantity(String lineId, int quantity) {
    if (quantity <= 0) {
      removeLine(lineId);
      return;
    }
    state = [
      for (final item in state)
        if (item.id == lineId) item.copyWith(quantity: quantity) else item,
    ];
  }

  void updateLineNotes(String lineId, String notes) {
    final trimmed = notes.trim();
    state = [
      for (final item in state)
        if (item.id == lineId)
          item.copyWith(
            notes: trimmed.isEmpty ? null : trimmed,
            updateNotes: true,
          )
        else
          item,
    ];
  }

  void removeLine(String lineId) {
    state = state.where((item) => item.id != lineId).toList();
  }

  void replaceAll(List<QuoteRequestItem> items) => state = List.of(items);

  void clear() => state = [];

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
