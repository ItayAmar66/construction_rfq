# Pre-Launch QA Report

**Project:** construction-rfq-itay-20-2eee0  
**Last updated:** 2026-06-16  
**Commit under test:** `e63e2a8` → post-fix commit pending  

## P0 — Supplier quote eligibility (Firestore rules)

| Check | Status | Notes |
|-------|--------|-------|
| Supplier A invited can create quote | **Fixed (rules)** | `supplierEligibleToQuoteRequest` + org invite match |
| Supplier B invited can create quote | **Fixed (rules)** | Same |
| Supplier C non-invited direct quote denied | **Fixed (rules)** | Removed legacy open-RFQ loophole |
| Supplier C linked request patch denied | **Fixed (rules)** | `supplierCanUpdateRequestResponse` |
| Duplicate quote denied | **Pass** | Existing deterministic doc id guard |
| openToAllSuppliers allows quote | **Fixed (rules)** | Explicit flag only |
| Contractor cannot create supplier quote | **Pass** | `isSupplier()` on create |
| Supplier viewer read-only | **Fixed (rules)** | `activeSupplierOrgCanQuote` excludes viewer |

**Root cause:** `supplierQuoteCreateAllowed()` did not verify invite/open eligibility; `supplierCanReadRequest` allowed any supplier when invite constraints were absent.

**Verification:**
- Static: `flutter test test/supplier_quote_eligibility_rules_test.dart`
- Emulator: `firebase emulators:exec --only firestore --project construction-rfq-rules-test "cd test/firestore && npm install && npm test"` (requires Java)

## P1 — Route persistence / deep links

| Route | Status | Notes |
|-------|--------|-------|
| `/catalog?projectId=qa-proj-alpha` | **Fixed (app)** | Path URL strategy + auth redirect preserves deep links |
| `/projects/qa-proj-alpha` | **Fixed (app)** | Bootstrap no longer forces `/` → `/home` |
| `/compare-quotes/:requestId` | **Fixed (app)** | Same |
| `/request-confirmation` | **Fixed (app)** | Same |

**Root cause:** GoRouter redirect sent non-splash routes to `/` during auth/membership loading; hash URLs without path strategy.

**Verification:**
- `flutter test test/router/app_route_guard_test.dart`
- Manual: open each URL while logged in, refresh, confirm same screen

## P2 — Mobile dashboard clipping (390×844)

| Check | Status |
|-------|--------|
| Bottom KPI tile visible above nav | **Fixed (app)** — increased scroll bottom padding on narrow layouts |

## Remaining manual checks

1. Live Supplier C write attempt against targeted RFQ (expect permission-denied).
2. Full happy-path RFQ by procurement/engineer/suppliers on deployed build.
3. Browser refresh on deep links after hosting deploy with path URLs.

## Launch readiness

- **P0:** Ready after rules deploy + emulator pass
- **P1:** Ready after hosting deploy + manual deep-link smoke
- **P2:** Low risk UX fix included
