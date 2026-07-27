# Scalability Fix Report — construction_rfq

Date: 2026-07-28
Source reports: `PERFORMANCE_REPORT.md`, `SCALABILITY_AND_COST_REPORT.md` (2026-07-27)

Scope of this pass: implement every remaining **safe** optimization from the two reports — no architecture redesign, no product-behavior change. Measure with `flutter analyze` / `flutter test` before and after.

---

## Baseline

Both source reports already reflect a prior pass that applied 9 safe fixes (H5, H6, M1–M4, M6, M9, L1 — see "Applied Fixes" table in `PERFORMANCE_REPORT.md`). Verified those are present on this branch (audit indexes, parallelized membership fetch, bounded cache size, debounced draft persistence, derived quote-count providers, `ListView.builder` in workspace tabs, batched approval writes, `.limit(50)` on pending-access-requests, parallelized product-chunk lookups).

Before this pass:
- `flutter analyze`: no issues
- `flutter test`: full suite green (926 tests)

## What was reviewed and NOT changed

The two reports are explicit that the highest-impact items (C1 marketplace-wide supplier listener, C2 full-collection "mark seen" scans, C3 eager 500-project dashboard list, H1 KPI aggregation, H2 provider `.select()` granularity, H3 chart memoization, H4 per-project summary precompute, M5 admin list virtualization, M8 org-name scan, M10 catalog category+text search, M12 image disk cache) all require a query-shape change, schema addition, product sign-off on a recency/pagination window, or a sliver/provider restructure — i.e. they are correctly flagged 📐, not 🔧, in the source reports. Per this task's constraints (no architecture redesign, no behavior change), none of these were touched. Implementing any of them safely is exactly the "Recommended order for follow-up work" already laid out in `PERFORMANCE_REPORT.md` and needs a dedicated design pass, not a mechanical edit.

Also reviewed and left alone as correctly non-duplicative: `_watchApprovedQuotesBySupplier` / `_watchShippedQuotesBySupplier`'s two-listener merge in `supplier_quote_repository.dart` — these cover genuinely distinct data (per-user `supplierId` scope vs. per-company `supplierOrgId` scope), unlike the M3 case (three listeners over the *identical* query), so merging them would change what data supplier-org members see.

## Fix applied this pass

### M7 — N+1 org lookup in supplier directory fallback path

**Files:** `lib/repositories/organization_repository.dart`, `lib/services/supplier_directory_service.dart`

`SupplierDirectoryService._listFromSupplierDirectory()` — the fallback path used only when the primary org query errors or returns empty — looped `await _organizationRepository.getOrganization(orgId)` once per `supplierDirectory` document, i.e. up to 100 sequential single-doc reads (one Firestore round-trip each) for a single directory list load at target scale.

Fix: added `OrganizationRepository.getOrganizationsByIds()`, a batched lookup using `whereIn(FieldPath.documentId, chunk)` in chunks of 10 — the same chunking pattern already used by `RequestRepository.getRequestsByIds` and `ProjectRepository.mergeAssignmentGroup`. `_listFromSupplierDirectory` now collects all needed org IDs first, resolves them in one batched call, then builds the supplier list from the resulting map. Same output, same ordering (sorted by name as before), same fallback semantics — purely a read-count/round-trip reduction (up to 100 sequential reads → at most 10 parallelizable `whereIn` batches).

No behavior change: only exercised when the primary path fails/empties, and the returned `AppUser` list content is identical to before.

## Verification

- `flutter analyze`: **no issues found** (after changes)
- `flutter test`: **full suite green** (926 tests, including `test/supplier_directory_service_test.dart`)

## Recommendation

The remaining high-value items are unchanged from the source reports' own "Recommended order for follow-up work": C1+C2 (supplier inbox fan-out / mark-seen scans) first, then C3+H4 (dashboard list + per-project summary), then H1 (server-side count aggregates), then H2→H3 (provider slice granularity). Each needs a scoping decision (recency window, pagination UX, or a schema/provider restructure) before it can be implemented without changing what users currently see — i.e. before it can be done "safely" under this task's constraints.
