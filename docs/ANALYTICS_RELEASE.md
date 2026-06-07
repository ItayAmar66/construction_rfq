# Analytics — release scope

## Current state

- `CatalogRfqAnalytics` tracks catalog RFQ events (selector opened, item selected, manual item, exact/alternative quote, approval with alternatives).
- **Release builds:** `NoOpCatalogRfqAnalytics` — events discarded.
- **Debug builds:** `DebugCatalogRfqAnalytics` — `debugPrint` only.

## Product claims

**Do not claim** production analytics dashboards or funnel tracking until Firebase Analytics / external provider is wired.

## Dashboard charts

- Customer/supplier dashboard KPIs use Firestore-backed providers; demo mode may use mock chart data.
- Charts are operational UI, not exported analytics.

## Future integration

Swap `catalogRfqAnalyticsProvider` implementation; keep `CatalogRfqEventNames` stable.

## QA

- `test/catalog_rfq_analytics_test.dart`
