# Performance Report — construction_rfq

Date: 2026-07-27
Scope: Flutter app + Firestore backend, evaluated against a target production scale of:
- 100 users, 500 projects, 10,000 RFQs, 100 suppliers
- Large per-supplier catalogs (thousands of products/variants)

Method: four parallel audits covering (1) Firestore reads/writes/queries/indexes, (2) catalog search & large-catalog handling, (3) Flutter rendering/rebuilds/memory/CPU, (4) offline/slow-network/dashboard load. Findings below are consolidated, deduplicated, and ranked. Each item lists severity, location, and whether a safe fix was applied in this pass.

Legend: 🔧 = fixed in this pass (safe, isolated, tests green) · 📐 = needs design work, not applied.

---

## Critical

### C1. Supplier "incoming requests" fans out into 4 unbounded platform-wide listeners
**File:** `lib/repositories/request_repository.dart:115-247` (`watchIncomingRequestsForSupplier`)
Opens 4 separate `.snapshots()` listeners (openToAll, targeted, orgTargeted, responded) with no `.limit()`, holds all matching docs in memory, and re-sorts/re-filters the full merged set on every snapshot from any of the 4. At 10,000 RFQs, every one of the 100 suppliers holds 4 live listeners that can each match a large fraction of the platform-wide `quoteRequests` collection, recomputing a full client-side filter/sort on every write anywhere in that set. This is the single biggest read-cost and CPU-cost driver in the app at target scale.
📐 Needs design work — narrow the query (per-supplier "inbox" denormalization or bounded pagination), not a same-session fix.

### C2. Full-collection scan on "mark requests as seen" (supplier + customer)
**File:** `lib/services/quote_service.dart:944-979` (`markIncomingRequestsSeenBySupplier`), `:904-942` (`markCustomerRequestsStatusSeen`)
`markIncomingRequestsSeenBySupplier` queries `quoteRequests` with only a `status whereIn [...]` filter — no supplier/org scoping — pulling every open RFQ platform-wide, parsing each, then filtering client-side for the current supplier before a batched write. Runs on every "open incoming requests" action. At 10,000 RFQs with hundreds-to-low-thousands open at once, this is a full collection scan+parse per supplier interaction.
📐 Needs design work — requires a supplier/org-scoped query or a "last seen" cursor design.

### C3. Dashboard project list renders all 500 projects eagerly, no lazy building
**File:** `lib/widgets/projects/dashboard_projects_section.dart:183-201`
Every project renders via a plain `Column`/`for` loop inside the dashboard's outer `ListView` — all 500 `_ProjectCard`s are built, laid out, and painted on every dashboard load, none offscreen-culled. Each `_ProjectCard` additionally does its own `ref.watch(projectProcurementSummaryProvider(project.id))` — 500 separate provider instantiations per build (see H-series below for the provider cost itself). This is the top rendering-side cost at 500-projects-per-org scale.
📐 Needs design work — requires either lazy list rendering restructured around the existing outer scrolling container (sliver-based layout), or capping the dashboard to top-N with a "view all" link to a paginated list screen. Not a mechanical `.builder()` swap because it's nested inside another scrolling `ListView`.

---

## High

### H1. Dashboard KPIs computed by downloading entire request/quote history, no server-side aggregation
**Files:** `lib/providers/dashboard_analytics_provider.dart:64-144`, `lib/providers/dashboard_tasks_provider.dart:24-138`, backing streams in `lib/providers/providers.dart:111-217`
None of the six dashboard-backing `StreamProvider`s (`customerRequestsProvider`, `customerReceivedQuotesProvider`, `incomingRequestsProvider`, `supplierSentQuotesProvider`, `supplierOrdersToFulfillProvider`, `supplierOrderHistoryProvider`) use `.limit()`. Every dashboard visit downloads a user's *entire* RFQ/quote history and computes counts/totals client-side (`.length`, `.where().length`) rather than using Firestore `count()` aggregate queries. At scale (a long-lived customer with hundreds of historic RFQs, or a supplier with years of history), every dashboard load re-fetches and re-parses the full document set to show a handful of numbers.
📐 Needs design work — add `.limit()` to the list-backing streams and introduce separate `count()` aggregate queries for the KPI numbers specifically (pattern already exists correctly in `AdminRepository`, see "Well-handled patterns" below).

### H2. No `.select()` anywhere — broad `ref.watch()` cascades full-screen rebuilds
**Files:** `lib/screens/customer/customer_dashboard_screen.dart:51-79`, `lib/screens/supplier/supplier_dashboard_screen.dart:40-58`, `lib/providers/dashboard_analytics_provider.dart`
Zero uses of Riverpod's `.select()` in the codebase. Dashboard screens watch 9+ providers directly in `build()`; a change to any single field (e.g. one quote's read-state) reruns the whole `build()`, reconstructing the entire subtree including the 500-item project list (C3) and all charts. The bundled analytics objects (9+ unrelated fields per record) make this worse — a KPI tile rebuilds when an unrelated field in the same record changes.
📐 Needs design work — split analytics providers into per-KPI `Provider`s and/or scope dashboard tiles behind `.select()` or small `Consumer` widgets.

### H3. Chart-data computation runs unmemoized inside `build()`
**Files:** `lib/widgets/dashboard/dashboard_charts.dart:465-482,564-590`, `lib/utils/dashboard_chart_data.dart`
Five to six full-list passes (monthly spend grouping, weekly counts, request/quote comparison grouping, status breakdowns, per-project spend) are called as plain functions directly inside `build()`, not behind a `Provider`. They recompute on every rebuild — including the H2 cascade — and aren't cached/shared across widgets that need the same derived values.
🔧 **Partially addressable safely, but full fix (promoting each computation to its own `Provider`) touches enough call sites that it was deferred this pass** — flagged for a focused follow-up; isolated and mechanical once H2 lands.

### H4. Per-project procurement summary re-scans the full request/quote lists per project
**File:** `lib/providers/project_providers.dart:77-94` (`projectProcurementSummaryProvider`)
This family provider re-filters and re-merges the *entire* customer+org request lists (with an O(n log n) sort) for every distinct `projectId` it's watched with. Combined with C3 (500 cards each instantiating this family provider), this is O(projects × requests) work triggered on every dashboard load.
📐 Needs design work — precompute a single `Map<projectId, ProjectProcurementSummary>` once, indexed by project, instead of a per-project scan.

### H5. Missing `auditEvents` composite index
**File:** `lib/repositories/audit_repository.dart:34-77` (`watchOrgEvents`/`watchProjectEvents`); `firestore.indexes.json`
Queries filter on `orgId`/`projectId` and order by `createdAt` — a composite index requirement — but `firestore.indexes.json` has no `auditEvents` entry at all. This is as much a correctness/availability risk (query can fail with `FAILED_PRECONDITION` if not auto-created via console) as a performance one; audit trails are used across project/org detail pages.
🔧 **Fixed** — added the two composite indexes to `firestore.indexes.json` (see Applied Fixes).

### H6. N+1 sequential org→membership reads on admin screen
**File:** `lib/repositories/admin_management_repository.dart:113-120` (`fetchAllMemberships`)
Fetched all orgs (600+ at target scale: 500 contractor + 100 supplier), then looped `await fetchMembershipsForOrg(org.id)` **serially** — one round-trip per org, not parallelized. 600 sequential Firestore round-trips for one admin screen load.
🔧 **Fixed** — parallelized with `Future.wait` (see Applied Fixes). Still N reads, but concurrent instead of serial; a `collectionGroup` rewrite would reduce read count further but is a larger change deferred as 📐.

---

## Medium

### M1. Firestore offline cache size unbounded
**File:** `lib/main.dart:34-38`
`Settings(persistenceEnabled: true)` with no `cacheSizeBytes` defaults to unlimited on-disk cache. At 10k RFQs × line items × quotes, the cache can grow indefinitely with no eviction.
🔧 **Fixed** — set `cacheSizeBytes: 100 * 1024 * 1024` (100MB) explicitly (see Applied Fixes).

### M2. Un-debounced per-keystroke local persistence in RFQ draft notes
**File:** `lib/providers/rfq_draft_provider.dart` (`updateLineNotes` → `_persist`)
Every keystroke in a draft line's notes field triggered a full `jsonEncode` of the entire draft plus a synchronous `SharedPreferences.setString` disk write — no debounce. Jank/battery cost scales with draft size and typing speed, worse on web (SharedPreferences backs onto browser storage) and low-end devices.
🔧 **Fixed** — added a 400ms debounce specifically for the notes-update path; other mutations (add/remove/quantity) remain immediate since they're low-frequency (see Applied Fixes).

### M3. Duplicate live listeners for identical quote data
**File:** `lib/providers/providers.dart:129-177` (was: `quoteCountByRequestProvider`, `unreadQuoteCountByRequestProvider`)
Both count providers independently called `watchCustomerReceivedQuotes(user.id)`, opening their own Firestore listener over the same data already held by `customerReceivedQuotesProvider` — 3x the necessary open listeners per customer session for identical underlying reads.
🔧 **Fixed** — both are now plain `Provider`s deriving from the already-watched `customerReceivedQuotesProvider` stream instead of separate `StreamProvider`s (see Applied Fixes).

### M4. `ListView(children: [for...])` instead of `.builder` in project workspace tabs
**File:** `lib/screens/projects/project_workspace_screen.dart` (`_RfqsTab`, `_QuotesTab`, `_OrdersTab`, `_DeliveriesTab`)
All four tabs eagerly built their full children list instead of lazily building via `ListView.builder`. Bounded by a single project's RFQ/quote/delivery counts today (not the 500-project total), but unbounded against a project's lifetime history and an easy, zero-risk fix.
🔧 **Fixed** — converted all four tabs to `ListView.builder` (the orders tab uses an index-based trailing-summary-row pattern to preserve its footer card) (see Applied Fixes).

### M5. Eager rendering in admin project/org list screens
**Files:** `lib/screens/admin/admin_projects_screen.dart:43-76`, `lib/screens/admin/admin_org_list_screen.dart:78-116`
Same `Column`/`for` pattern as C3, over platform-wide project/org lists. Admin-only, lower traffic, but same shape of problem at 500+ projects / 600+ orgs.
📐 **Not applied this pass** — these lists are nested inside an outer page-level `ListView` (header button + section), so a mechanical swap to `ListView.builder` isn't sufficient (nested unbounded-height lists either throw or, with `shrinkWrap: true`, still force full eager layout, defeating the purpose). A correct fix needs a `CustomScrollView`/sliver restructure of the outer screen. Flagged for a dedicated pass rather than risking a rushed, ineffective change.

### M6. Sequential per-project assignment writes on access-request approval
**File:** `lib/services/user_approval_service.dart:106-124` (`approveAccessRequest`)
Looped `await ... .set(...)` once per assigned project instead of a single `WriteBatch`. Typically small N (a handful of projects per approval) so today's impact is low, but it's a trivial, safe batch-write fix and a bad pattern worth not propagating.
🔧 **Fixed** — converted to a single `WriteBatch` (see Applied Fixes).

### M7. N+1 org lookup in supplier directory fallback path
**File:** `lib/services/supplier_directory_service.dart:69-108` (`_listFromSupplierDirectory`)
The *fallback* path (used when the primary org query errors/returns empty — a real production edge case) does one `await getOrganization(orgId)` per supplier-directory doc inside a loop — 100 sequential single-doc reads at target scale for a list screen.
📐 Needs design work — batch via `whereIn(FieldPath.documentId, chunk)`, matching the pattern already used elsewhere in the codebase. Deferred since the fallback path isn't exercised in the tests examined and warrants a dedicated verification pass.

### M8. `AccessRequestRepository.resolveOrgIdByName` full-collection scan
**File:** `lib/repositories/access_request_repository.dart:138-156`
Fetches all orgs of a type/status and matches by name client-side instead of querying a normalized field directly.
📐 Needs design work — requires adding/maintaining a `nameLower` field on organizations (pattern already used in catalog), a small schema/data-migration concern, not a same-session fix.

### M9. `fetchPendingForOrg` had no `.limit()`
**File:** `lib/repositories/access_request_repository.dart:33-64`
Unbounded `.get()`, unlike its sibling `fetchAllPending()` which already caps at 50.
🔧 **Fixed** — added `.limit(50)` to match (see Applied Fixes).

### M10. Category+text catalog search over-fetches and filters client-side
**File:** `lib/repositories/catalog_search/firestore_catalog_search_repository.dart:95-136`
When both a category and a text token are set, Firestore can't combine two `array-contains` filters in one query, so the code fetches up to `(limit+1)*4` docs (clamped to 200) filtered only by token server-side, then filters by category client-side. Can require several "Load More" round-trips per page if category density in the token-matched set is low. This is a reasonable workaround for a genuine Firestore limitation, not a bug.
📐 Needs design work — e.g. a materialized composite `categorySearchTokens` field built at catalog-import time.

### M11. Dashboard streams beyond one have no timeout/error fallback
**File:** `lib/providers/providers.dart` (5 of 6 dashboard streams), contrast with `lib/repositories/request_repository.dart:85-89` + `lib/utils/platform_access_gate.dart:15`
`watchCustomerRequests` has a bootstrap timeout (10s release / 0s debug) that falls back to an empty list if no snapshot arrives. The other five dashboard streams have no equivalent — on a stalled network they'll just remain empty/absent with no way to distinguish "still loading" from "genuinely empty" from "network stalled."
📐 Needs design work — extend the existing bootstrap-timeout pattern to the other five streams.

### M12. No disk-persistent image cache for catalog thumbnails
**File:** `lib/widgets/catalog/catalog_product_image.dart:89-108`
Uses `Image.network` with well-tuned `cacheWidth`/`cacheHeight` (good — decode resolution is capped) but only Flutter's in-memory `ImageCache`. Every cold restart or fresh route re-downloads thumbnails already viewed this session. At 100 suppliers × thousands of products, this is real repeat bandwidth for frequent catalog browsers.
📐 Needs design work — adopt `cached_network_image` (new dependency) while preserving the existing sizing/web-strategy logic; a dependency addition warrants its own review, not bundled into this pass.

---

## Low

- **L1.** `firestore_catalog_search_repository.dart:177-193` (`_loadProducts`) chunked `whereIn` product lookups (max 10 per Firestore limit) but awaited each chunk **sequentially**. 🔧 **Fixed** — parallelized with `Future.wait` (see Applied Fixes).
- **L2.** `getCategoryTree()` (`firestore_catalog_search_repository.dart:53-58`, `firestore_catalog_repository.dart:46-51`) does an unbounded `.get()` — fine at expected category-tree scale (hundreds, not thousands), flagged only as a latent risk if the category tree grows unexpectedly.
- **L3.** `RequestRepository.watchCustomerRequests`/`watchContractorOrgRequests`, `SupplierQuoteRepository.watchCustomerReceivedQuotes`/`watchSupplierSentQuotes` have no `.limit()`, but are scoped to one actor's history (not the 10k platform total) — low risk today, worth pagination before GA for long-lived high-volume accounts.
- **L4.** `OrganizationRepository.watchAccessibleProjects` (`lib/repositories/project_repository.dart:91-362`) opens several listeners per membership org (bounded by membership count, not the 500-project total) — not urgent at stated scale.
- **L5.** Redundant `LayoutBuilder` breakpoint recomputation across ~8 independent dashboard chart cards (`lib/widgets/dashboard/responsive_dashboard_layout.dart`, `dashboard_charts.dart:40`) — cheap arithmetic, only matters under frequent resize (desktop/web); not applied.
- **L6.** Dead/unwired duplicate catalog repository code (`lib/providers/catalog_providers.dart:7-9`, `lib/repositories/catalog/firestore_catalog_repository.dart`) including a latent pagination-cursor bug (`nameLower` non-unique used as a cursor) that would only matter if this repository is ever wired to the UI — currently isn't. Code-hygiene, not a live perf issue.
- **L7.** `dashboard_projects_section.dart` pending-deletion list has the same eager-`Column` shape as C3 at smaller scale — will be addressed together with C3.
- **L8.** No optimistic UI on project creation (`customer_dashboard_screen.dart:398-424`) — list only updates after the write round-trip resolves. Minor UX-latency issue on slow networks, not a systemic perf problem.

---

## Well-handled patterns (no action needed — noted as the template for the 📐 items above)

- `AdminRepository` (`lib/repositories/admin_repository.dart`) consistently uses `.limit()`/`.orderBy()` and Firestore `count()` aggregate queries for dashboard stats — the pattern H1 should be generalized to.
- `RequestRepository.getRequestsByIds`, `ProjectRepository.mergeAssignmentGroup` correctly chunk `whereIn` lookups into batches of 10.
- `QuoteService.markCustomerReceivedQuotesSeen` and related status-flip helpers properly use `WriteBatch`, chunked at 450 writes (under the 500-write Firestore limit).
- Catalog search-query construction matches its Firestore composite indexes exactly; debounced search input (300ms); manual "Load More" pagination with real document cursors (not offset-based) — solid foundation, no full-collection-scan search patterns found.
- Connectivity handling (`connectivity_plus`, event-based, no polling) and cache-first dashboard rendering (data providers read via `valueOrNull ?? []`, never blocking the UI) are both sound as-is.
- No memory leaks found in spot-checked `AnimationController`/`TextEditingController`/`StreamSubscription`/`FocusNode` usage; no heavy synchronous compute found off the documented hot paths; no systemic missing-`const` pattern.

---

## Applied Fixes (this pass)

All fixes below are isolated, low-risk, and verified with `flutter analyze` (no issues) and the relevant existing test suites (all green — `rfq_draft_persistence_test.dart`, `rfq_request_items_persistence_test.dart`, `rfq_draft_provider_test.dart`, `user_approval_flow_test.dart`, `admin_management_test.dart`, `access_request_repository_test.dart`, plus the project-workspace-touching sprint suites). No behavior changes beyond the stated performance improvements.

| # | Fix | File(s) |
|---|---|---|
| H5 | Added missing `auditEvents` composite indexes (`orgId`+`createdAt`, `projectId`+`createdAt`) | `firestore.indexes.json` |
| H6 | Parallelized per-org membership fetch with `Future.wait` instead of a sequential loop | `lib/repositories/admin_management_repository.dart` |
| M1 | Set explicit Firestore offline cache size (100MB) instead of unbounded | `lib/main.dart` |
| M2 | Debounced (400ms) local-draft persistence specifically for the notes-field update path | `lib/providers/rfq_draft_provider.dart` |
| M3 | Converted `quoteCountByRequestProvider`/`unreadQuoteCountByRequestProvider` from independent `StreamProvider`s to derived `Provider`s off the existing `customerReceivedQuotesProvider` stream | `lib/providers/providers.dart` |
| M4 | Converted all 4 project-workspace tabs from eager `ListView(children:[for...])` to `ListView.builder` | `lib/screens/projects/project_workspace_screen.dart` |
| M6 | Replaced sequential per-project assignment writes with a single `WriteBatch` | `lib/services/user_approval_service.dart` |
| M9 | Added `.limit(50)` to `fetchPendingForOrg`, matching its sibling `fetchAllPending()` | `lib/repositories/access_request_repository.dart` |
| L1 | Parallelized `whereIn` product-lookup chunks with `Future.wait` instead of sequential `for`-loop awaits | `lib/repositories/catalog_search/firestore_catalog_search_repository.dart` |

**Deliberately not applied** (correctly flagged as "safe" by initial analysis but found to need more care on inspection): M5 (admin list lazy-rendering — requires a sliver restructure of the outer screen, not a mechanical builder swap); C3/H1/H2/H4/C2/C1 and the remaining 📐 items above, all of which require query/schema/architecture changes beyond a same-session isolated edit.

---

## Recommended order for follow-up work

1. **C1 + C2** (supplier inbox fan-out + full-scan "mark as seen") — highest read-cost impact at 10k-RFQ scale; both point at the same root cause (no supplier/org-scoped index on the "open requests" query shape) and should be designed together.
2. **C3 + H4** (500-project dashboard) — highest client-side CPU/memory impact; also share a root cause (`projectProcurementSummaryProvider` re-scanning) and should be fixed together (precompute the per-project map once, then lazily render).
3. **H1** (server-side count aggregates for KPIs) — moderate effort, high payoff, unblocks removing several unbounded `.get()`s.
4. **H2 → H3** (provider-slice granularity) — architectural but mechanical once started; unlocks safely fixing H3 fully and reduces the blast radius of every future dashboard change.
5. Everything else in Medium/Low as capacity allows; M5, M7, M10, M12 are the highest-value remaining items.
