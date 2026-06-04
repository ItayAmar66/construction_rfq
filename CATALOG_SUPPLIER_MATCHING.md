# Catalog supplier quote matching (Phase 7–8)

Suppliers see catalog identity on RFQ lines and declare **exact** vs **alternative** intent when quoting. Customers see side-by-side requested vs quoted lines before approving.

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

## Customer compare & approval (Phase 8)

| Screen | Path |
|--------|------|
| Compare quotes | `lib/screens/customer/quote_compare_screen.dart` |
| Quote detail / approve | `lib/screens/customer/customer_quote_detail_screen.dart` |

Shared widget: `CustomerQuoteLineMatchCard` (`lib/widgets/catalog/customer_quote_line_match_card.dart`)

For each quoted line linked to a catalog RFQ item:

- **Requested snapshot** — `QuoteRequestCatalogSnapshot` from the matching `QuoteRequestItem`
- **Supplier offer** — quoted name, SKU, price
- **Badge** — `SupplierQuoteMatchBadge`: **התאמה מדויקת** or **חלופה**
- **Alternative notes** — supplier notes highlighted when `isAlternative`

Manual lines render as plain product rows with no catalog badges.

Approval uses `CustomerQuoteApprovalDialog`: when any line is an alternative, a warning appears before confirm. The customer can still approve; approval business rules are unchanged.

Helpers: `lib/utils/customer_quote_match_helpers.dart` — request-line lookup, alternative detection.

## Not in scope

- No automated pricing or catalog price lookup
- Supplier quote creation logic unchanged
- No production catalog import changes

## Related docs

- `CATALOG_SELECTOR_UI.md` — customer catalog picker + RFQ draft integration
