# Catalog supplier quote matching (Phase 7)

Suppliers see catalog identity on RFQ lines and declare **exact** vs **alternative** intent when quoting.

## Supplier UI

| Screen | Path |
|--------|------|
| Regular quote | `lib/screens/supplier/supplier_quote_response_screen.dart` |
| Tender bid | `lib/screens/supplier/tender_bid_screen.dart` |

Catalog-matched request lines show:

- `QuoteRequestCatalogSnapshot` — displayName, SKU, unit/package, category path, **מהקטלוג** badge
- `SupplierCatalogMatchControls` — **מציע בדיוק את הפריט** / **מציע חלופה**
- Alternative mode exposes quoted name + SKU fields

Manual RFQ lines keep the existing price/notes form with no match controls.

## Persisted quote line fields (`SupplierQuoteItem`)

| Field | Purpose |
|-------|---------|
| `requestItemId` | Links to RFQ line |
| `variantId` | Catalog variant when exact match |
| `productId` | Request product id |
| `quotedName` / `productName` | Name shown on quote |
| `quotedSku` | SKU offered |
| `unitPrice` / `totalItemPrice` | Pricing (unchanged) |
| `isExactMatch` | Supplier offers requested catalog item |
| `isAlternative` | Supplier offers substitute |
| `supplierNotes` | Line-level availability notes |

Built via `SupplierQuoteLineMapper.fromRequestLine()`.

## Customer compare

`quote_compare_screen.dart` shows `SupplierQuoteMatchBadge`:

- **התאמה מדויקת** when `isExactMatch`
- **חלופה** when `isAlternative`

Uses `displayName` (`quotedName` fallback to `productName`).

## Not in scope

- No automated pricing or catalog price lookup
- Customer approval logic unchanged
- No production catalog import changes

## Related docs

- `CATALOG_SELECTOR_UI.md` — customer catalog picker + RFQ draft integration
