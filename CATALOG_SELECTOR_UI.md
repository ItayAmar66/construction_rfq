# Catalog selector UI (Phase 5)

First UI for picking **catalog variants** into a future RFQ line. Uses `CatalogSearchRepository` — not wired to live RFQ create, cart, or legacy `ProductService`.

## Components

| Piece | Path |
|-------|------|
| Screen | `lib/screens/catalog/catalog_selector_screen.dart` |
| Sheet | `lib/widgets/catalog/catalog_selector_sheet.dart` |
| Variant card | `lib/widgets/catalog/catalog_variant_result_card.dart` |
| State | `lib/providers/catalog_selector_provider.dart` |
| Draft line | `lib/models/catalog/catalog_rfq_line_draft.dart` |
| Demo (debug) | `lib/screens/catalog/catalog_selector_demo_screen.dart` |

## Features

- Search field (submit to search)
- Category browse chips (horizontal)
- Paginated variant results + **Load more**
- SKU / unit / packaging / category breadcrumb on cards
- Loading, error, empty states
- **Select variant** → returns `CatalogRfqLineDraft`

## Draft output (`CatalogRfqLineDraft`)

```dart
CatalogRfqLineDraft.fromSearchHit(hit);
// variantId, productId, categoryId, categoryPath, displayName,
// sku, unitType, packagingLabel, quantity: 1, notes: '', isCatalogMatched: true
```

## Usage

### Full screen (returns draft via `pop`)

```dart
final draft = await context.push<CatalogRfqLineDraft>(
  MaterialPageRoute(builder: (_) => const CatalogSelectorScreen()),
);
```

### Bottom sheet

```dart
final draft = await CatalogSelectorSheet.show(context);
```

### Debug demo route

`kDebugMode` only: navigate to `/dev/catalog-selector` to try screen + sheet without touching RFQ create.

## Integration plan (Phase 6+)

1. Add optional catalog line type on RFQ draft model (parallel to legacy `QuoteRequestItem`).
2. Wire **Add from catalog** on cart / edit-request behind feature flag.
3. Map `CatalogRfqLineDraft` → persisted RFQ item when catalog cutover is approved.
4. Keep legacy `products` + `ProductService` until full migration.

## Not in scope

- No production writes from selector
- No checkout / e-commerce cart merge
- No replacement of `/catalog` legacy product screen
