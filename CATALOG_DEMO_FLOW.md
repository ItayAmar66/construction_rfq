# Catalog RFQ demo flow (investor / QA)

Demo mode: log in as **customer demo** → build RFQ → submit → switch to **supplier demo** → quote → back to customer → compare → approve.

## Customer path (catalog RFQ)

| Step | Route / screen | What to show |
|------|----------------|--------------|
| 1 | Dashboard → **בקשת הצעת מחיר** (`/cart`) | Empty draft or existing lines |
| 2 | **בחר מהקטלוג** | `CatalogSelectorSheet` — search / category browse |
| 3 | Add line | Catalog badge **מהקטלוג** on draft card |
| 4 | **הוסף פריט ידני** | Manual line without catalog badge |
| 5 | **שלח בקשה** | RFQ submitted |

Debug-only catalog picker demo: `/dev/catalog-selector` (`kDebugMode`).

Legacy product browse (optional): `/catalog` → product detail → **הוסף לבקשה** → `/cart`.

## Supplier path

| Step | Route / screen | What to show |
|------|----------------|--------------|
| 1 | Incoming requests | Open RFQ |
| 2 | Quote response | Catalog snapshot + **מציע בדיוק** / **מציע חלופה** |
| 3 | Submit quote | Match fields persisted |
| 4 | Sent quotes | Expand row — match badges + line context |
| 5 | Approved order | Order detail with match cards |

## Customer approval path

| Step | Route / screen | What to show |
|------|----------------|--------------|
| 1 | **הצעות שהתקבלו** | Summary chips; amber hint if alternatives |
| 2 | **השוואת הצעות** | Side-by-side lines, exact vs alternative |
| 3 | Approve quote with alternative | Warning dialog → still approves |
| 4 | Second quote on same RFQ | Blocked (one approval rule) |

## Copy conventions (Phase 9+)

- RFQ draft: **בקשת הצעת מחיר**, **חומרים בבקשה**, **הוסף לבקשה**
- No shopping-cart icons on catalog browse or product detail
- Route `/cart` kept for compatibility (internal `CartScreen`)

## Automated coverage

- `test/catalog_rfq_lifecycle_test.dart` — full service lifecycle
- `test/rfq_catalog_flow_qa_test.dart` — RFQ copy + catalog selector
- `test/customer_quote_approval_match_test.dart` — approval UX
- `test/supplier_quote_catalog_context_test.dart` — supplier line display

## Related docs

- `CATALOG_SELECTOR_UI.md` — selector + RFQ integration
- `CATALOG_SUPPLIER_MATCHING.md` — exact/alternative matching
- `CATALOG_PRODUCTION_DEPLOY_CHECKLIST.md` — production ops (no demo import)
