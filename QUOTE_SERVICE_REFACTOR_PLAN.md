# QuoteService refactor plan (Phase 27)

`QuoteService` (~1.3k lines) mixes Firestore IO, demo store, RFQ lifecycle, quotes, tenders, and orders.

## Safe extractions (done / next)

| Extract | Status | File |
|---------|--------|------|
| Request item resolution | **Done** | `lib/utils/quote_request_item_resolver.dart` |
| Quote decision metrics | Done (Phase 25) | `lib/utils/quote_decision_metrics.dart` |
| Customer match helpers | Exists | `lib/utils/customer_quote_match_helpers.dart` |

## Recommended next slices (no behavior change)

1. **`quote_request_persistence.dart`** — map Firestore doc ↔ `QuoteRequest` + embedded items
2. **`supplier_quote_persistence.dart`** — quote create/update/read
3. **`quote_approval_service.dart`** — approve/reject + one-quote rule
4. **`tender_service.dart`** — counter-bids, close tender, lowest bid

## Rules

- Extract **pure helpers first**, then thin Firestore adapters
- Keep `QuoteService` as facade until callers migrate
- Demo mode stays in `MockStore` — mirror interfaces per slice
- One PR per slice; full `flutter test` each time

## Not yet

- No Riverpod split
- No repository layer for quotes (catalog already has repos)
