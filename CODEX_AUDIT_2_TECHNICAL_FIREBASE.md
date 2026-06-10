# Construction RFQ - Codex Audit 2: Technical + Firebase

Date: 2026-06-07

## Status

Reset to `origin/main`; working tree clean. Audit only, no application code changes.

## Analyze

Failed. `flutter analyze` reports 8523 issues, mostly from `build/macos/SourcePackages/checkouts/flutterfire`; local warnings also exist.

## Tests

Passed on sequential rerun. `flutter test`: all tests passed, with one nonfatal widget tap warning.

## Technical Readiness Score

6/10

## Critical Blockers

1. Raw `flutter analyze` is not release-clean because generated/third-party `build/macos` files are being analyzed.
2. Firestore role escalation risk: users can create/update their own `/users/{uid}` document, including `userType`.
3. Firestore rules do not validate RFQ/quote schema, item shapes, prices, statuses, or catalog match fields server-side.

## Firebase/Security Risks

- Catalog collections are read-only for clients: good.
- No active client catalog write path found outside import/dev tooling.
- `quoteRequests`, `supplierQuotes`, `quoteRequestItems`, and `supplierQuoteItems` allow broad client-created data.
- Customers can update request status/approval fields client-side within `changedOnly`.
- Suppliers can create quote data with forged/invalid embedded items/prices as long as basic request/customer checks pass.
- Manual RFQ items are app-protected, but not rules-protected.

## Architecture Risks

- `QuoteService` split is partial; approval, tender bidding, shipment, seen-state, and batch side effects remain centralized.
- Notification service is no-op and not wired into lifecycle writes.
- Role helpers are UI/app-layer only; rules rely on mutable user profile role fields.

## Demo/Dead Code Risks

- Production catalog selector uses `FirestoreCatalogSearchRepository`, no demo fallback.
- Demo selector/admin routes are `kDebugMode` gated.
- Read-only admin ops has a demo snapshot helper for tests; low production risk.

## Top 10 Recommended Fixes

1. Exclude `build/` from analyzer or clean generated checkout before analyze.
2. Lock `/users/{uid}.userType` after creation or move roles to server/admin claims.
3. Add strict Firestore schema validation for `quoteRequests`.
4. Add strict Firestore schema validation for `supplierQuotes`.
5. Remove or lock top-level `quoteRequestItems` and `supplierQuoteItems` client creates.
6. Move approval/reject/ship/status transitions to Cloud Functions or enforce transitions in rules.
7. Validate supplier quote line prices, quantities, request item IDs, and catalog match flags server-side.
8. Enforce one active regular supplier quote per supplier/request server-side.
9. Wire notification hooks into RFQ lifecycle writes or remove the unused service from release scope.
10. Add emulator tests for malicious role change, forged catalog match, bad manual item, duplicate quote, and invalid approval transitions.
