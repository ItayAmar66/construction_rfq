# Catalog selector UI (Phase 5–6)

UI for picking **catalog variants** into RFQ request lines. Uses `CatalogSearchRepository`. Integrated into RFQ creation (`/cart`) and edit-request flows.

## Components

| Piece | Path |
|-------|------|
| Screen | `lib/screens/catalog/catalog_selector_screen.dart` |
| Sheet | `lib/widgets/catalog/catalog_selector_sheet.dart` |
| Variant card | `lib/widgets/catalog/catalog_variant_result_card.dart` |
| State | `lib/providers/catalog_selector_provider.dart` |
| Draft line | `lib/models/catalog/catalog_rfq_line_draft.dart` |
| RFQ draft | `lib/providers/rfq_draft_provider.dart` |
| Line card | `lib/widgets/rfq_draft_line_card.dart` |
| Manual add | `lib/widgets/manual_rfq_item_dialog.dart` |
| Demo (debug) | `lib/screens/catalog/catalog_selector_demo_screen.dart` |

## RFQ integration (Phase 6)

### Create request (`CartScreen` → `/cart`)

- **בחר מהקטלוג** opens `CatalogSelectorSheet`
- **הוסף פריט ידני** opens manual item dialog
- Selected catalog draft → `QuoteRequestItem.fromCatalogDraft()` via `rfqDraftProvider`
- Legacy catalog (`ProductService` / product detail) still imports into draft as manual lines
- Submit uses `QuoteService.submitQuoteRequest(requestItems: …)` with catalog snapshot fields persisted

### Edit request (`EditRequestScreen`)

- Same catalog + manual actions append to existing request items
- Catalog lines show **מהקטלוג** badge on `RfqDraftLineCard`

### Mapping

```dart
final item = QuoteRequestItem.fromCatalogDraft(draft, lineId: uuid);
// Persists: variantId, productId, categoryId, categoryPath, productName,
// sku, unitType, packagingLabel, quantity, notes, isCatalogMatched: true
```

Manual / legacy lines use `isCatalogMatched: false` (no `variantId`).

## Draft output (`CatalogRfqLineDraft`)

```dart
CatalogRfqLineDraft.fromSearchHit(hit);
// variantId, productId, categoryId, categoryPath, displayName,
// sku, unitType, packagingLabel, quantity: 1, notes: '', isCatalogMatched: true
```

## Usage

### Bottom sheet (RFQ create / edit)

```dart
final draft = await CatalogSelectorSheet.show(context);
if (draft != null) {
  ref.read(rfqDraftProvider.notifier).addCatalogDraft(draft);
}
```

### Debug demo route

`kDebugMode` only: `/dev/catalog-selector`

## Next steps

1. Surface catalog badge on supplier quote response / tender bid views
2. Deprecate legacy `/catalog` browse once catalog search covers all SKUs
3. Duplicate-request flow already preserves catalog fields via `rfqDraftProvider`

## Related docs

- `CATALOG_SUPPLIER_MATCHING.md` — supplier exact/alternative quote matching (Phase 7)

## Not in scope

- No production catalog import/write changes from UI
- No checkout / e-commerce cart behavior
- Legacy `ProductService` and `/catalog` remain available
