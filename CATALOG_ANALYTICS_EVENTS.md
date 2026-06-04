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
| `catalog_item_selected` | Variant chosen (selector or RFQ draft) |
| `manual_item_added` | Manual RFQ line added |
| `supplier_exact_quote` | Supplier submits exact catalog line |
| `supplier_alternative_quote` | Supplier submits alternative catalog line |
| `approval_with_alternatives` | Customer approves quote containing alternatives |

## Wiring

- Selector: `catalog_selector_screen.dart`
- RFQ draft: `cart_screen.dart`
- Supplier quote/tender: `supplier_quote_response_screen.dart`, `tender_bid_screen.dart`
- Customer approval: `customer_quote_detail_screen.dart`

## Tests

`test/catalog_rfq_analytics_test.dart`

## Later

Swap `NoOpCatalogRfqAnalytics` for Firebase Analytics / Amplitude when approved.
