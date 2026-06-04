# Supplier targeting foundation (Phase 26)

Enterprise-ready **models + helpers only** — no hard visibility cutover.

## Models

| Field | Location | Purpose |
|-------|----------|---------|
| `supplierCategoryIds` | `AppUser` | Supplier capability categories (optional) |
| `serviceAreas` | `AppUser` | Regions/cities served (existing) |
| `invitedSupplierIds` | `QuoteRequest` | Optional invite-only list |

## Helper

`lib/utils/supplier_targeting_helpers.dart`

- `matchesServiceArea` — city vs supplier areas
- `matchesRequestCategories` — category overlap with RFQ lines
- `isSupplierInvited` — empty list = broad visibility (fallback)
- `isSupplierRelevant` — combined check

## Current behavior

Incoming requests still use existing `QuoteService` / Firestore queries. Helpers are ready for future filtering — **suppliers not excluded yet**.

## Tests

`test/supplier_targeting_test.dart`
