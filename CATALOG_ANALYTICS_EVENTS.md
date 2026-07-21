# Catalog RFQ analytics events (Phase 19)

Lightweight hooks for catalog RFQ funnel — **no external SDK** yet.

## API

| File | Role |
|------|------|
| `lib/analytics/catalog_rfq_analytics.dart` | Event names, `CatalogRfqAnalytics` interface, no-op + debug impl |
| `catalogRfqAnalyticsProvider` | Riverpod provider (debug logs in `kDebugMode`) |

## Events

| Event | When |
|-------|------|
| `catalog_selector_opened` | Selector screen opens |
| `catalog_item_selected` | Variant chosen; `source` tags the entry point (`quick_add`, `detail_sheet`, `rfq_draft`, `edit_request`, `dashboard`, `catalog_browse`). Fires once per selection, not once per quantity bump. |
| `manual_item_added` | Manual RFQ line added |
| `supplier_exact_quote` | Supplier submits exact catalog line |
| `supplier_alternative_quote` | Supplier submits alternative catalog line |
| `approval_with_alternatives` | Customer approves quote containing alternatives |

## Wiring

- Selector (owns all `catalog_item_selected` tracking — embedders must not re-track the same pick): `catalog_selector_screen.dart`
- Embedding screens, each passing a distinct `selectionSource` into `CatalogSelectorSheet`/`CatalogSelectorScreen`: `cart_screen.dart` (`rfq_draft`), `edit_request_screen.dart` (`edit_request`), `customer_dashboard_screen.dart` (`dashboard`), `material_catalog_screen.dart` (`catalog_browse`)
- Supplier quote/tender: `supplier_quote_response_screen.dart`, `tender_bid_screen.dart`
- Customer approval: `customer_quote_detail_screen.dart`

## Tests

`test/catalog_rfq_analytics_test.dart`

## Later

Swap `NoOpCatalogRfqAnalytics` for Firebase Analytics / Amplitude when approved.
