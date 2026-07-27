# Firebase Scalability & Cost Report — construction_rfq

**Date:** 2026-07-27
**Scope:** Firestore, Firebase Storage, Firebase Auth, Cloud Functions, Hosting, Analytics, Crashlytics
**Stack:** Flutter (mobile + web) using `cloud_firestore` ^5.6, `firebase_auth` ^5.3, `firebase_storage` ^12.4, `firebase_analytics` ^11.6, `firebase_crashlytics` ^4.3. No Cloud Functions are currently deployed (`firebase.json` has no `functions` section; `tools/functions/README.md` documents a planned-but-unbuilt `sendInvitationEmail` callable).

This report is a **read-only architectural and cost analysis**. It does not change any application behavior. All recommendations at the end are explicitly scoped to preserve existing functionality.

---

## 1. Data model summary

Top-level collections (`lib/utils/constants.dart`, `lib/utils/catalog_constants.dart`):

`users`, `organizations` (+ `memberships` subcollection), `projects` (+ `assignments` subcollection), `quoteRequests` (RFQs, with an embedded `items[]` array), `supplierQuotes` (with embedded `items[]`), `invitations`, `accessRequests`, `auditEvents`, `supplierDirectory`, plus catalog reference data (`catalogProducts`, `catalogVariants`, `catalogCategories`, `catalogMeta`) and a legacy demo `products` collection.

Relationships are denormalized by foreign-key string fields (e.g. `supplierQuotes.requestId → quoteRequests`), not server-side joins. Legacy `quoteRequestItems`/`supplierQuoteItems` collections exist only as a fallback path when the embedded `items[]` array is empty.

---

## 2. Current architecture findings

### 2.1 Unbounded listeners (real-time `.snapshots()`)

Nearly every real-time listener in the app is **scoped by `where()` but not `limit()`** — result sets and re-fire frequency grow with the underlying collection, not with what's visible on screen. Bounded exceptions: `auditEvents` listeners (`audit_repository.dart:39-96`, explicit `limit(30/50)`) and catalog search (paginated).

Key unbounded listeners and where they run (all held open for the life of the screen/session):

| Listener | File | Scope |
|---|---|---|
| `watchCustomerRequests` | `request_repository.dart:59` | all of a customer's RFQs |
| `watchOrgPendingProcurement` / `watchContractorOrgRequests` | `request_repository.dart:496,513` | all of a contractor org's RFQs |
| `watchCustomerReceivedQuotes` | `supplier_quote_repository.dart:65` | all quotes received by a customer |
| `watchSupplierSentQuotes` | `supplier_quote_repository.dart:96` | all quotes sent by a supplier |
| `watchAccessibleProjects` (owner + per-org + per-project + collection-group) | `project_repository.dart:91-362` | fans out to **2 + 2×(orgs) + 2×(projects)** concurrent listeners per user |
| `watchIncomingRequestsForSupplier` | `request_repository.dart:191-236` | **4 parallel platform-wide listeners** per supplier session (open-to-all, invited-by-id, invited-by-org, responded) |
| `watchAuthSession` | `auth_service.dart:39-113` | 1 doc listener, held for the whole app lifetime, re-fetches the ID token on every `users/{uid}` change |

**The single most important structural finding:** `watchIncomingRequestsForSupplier`'s `openToAllSuppliers` sub-query (`request_repository.dart:191-204`) is a **marketplace-wide broadcast query** — every supplier company's session holds a live listener over the *entire platform's* pool of open RFQs, not just their own company's data. As the platform grows, both the matched-document count *and* the number of concurrently-listening sessions grow with total company count, so the read cost of this one listener scales roughly with the **square** of company count, not linearly. This is quantified in §4.

### 2.2 Duplicate reads

`customerReceivedQuotesProvider`, `quoteCountByRequestProvider`, and `unreadQuoteCountByRequestProvider` (`providers.dart:129-177`) each independently call `watchCustomerReceivedQuotes` — **three separate live Firestore listeners on the identical query** per customer session, instead of one shared stream with derived counts.

Similarly, `watchSupplierOrdersToFulfill` and `watchSupplierOrderHistory` each merge 2 parallel listeners (`supplier_quote_repository.dart:459-501`) to cover both `supplierId`- and `supplierOrgId`-scoped variants of the same logical query.

### 2.3 "Mark seen" full-collection scans

`markCustomerReceivedQuotesSeen`, `markCustomerRequestsStatusSeen`, `markIncomingRequestsSeenBySupplier`, `markSupplierOrdersToFulfillSeen` (`quote_service.dart:860-1039`) each run an **unbounded `where()` query over the user's entire history** to find the handful of documents that actually changed, then batch-write the ones that need a "seen" flag flip. Cost is O(total historical record count), not O(unseen count), and appears to run on every relevant screen visit.

### 2.4 N+1 patterns — mostly avoided

The codebase generally does this correctly: `getRequestsByIds` (`request_repository.dart:269-304`), `_loadProducts` (`firestore_catalog_search_repository.dart:177-193`), and `mergeAssignmentGroup` (`project_repository.dart:233-259`) all batch related-document lookups via `whereIn` chunks of 10, rather than issuing one read per related document in a loop. No true per-item-in-a-loop N+1 read pattern was found.

One caveat: `mergeAssignmentGroup` re-fetches the *entire* matched project set via `whereIn` on every collection-group snapshot event, not just the delta (`project_repository.dart:246-257`) — a smaller, bounded inefficiency, not a growth risk.

### 2.5 Pagination

Implemented correctly for catalog search (`firestore_catalog_search_repository.dart:82-175`, cursor-based via `startAfterDocument`, capped at 200/page) and catalog import. **Not implemented** for RFQ/quote/project lists — these rely entirely on live, unbounded listeners (see §2.1). Admin dashboard list fetches (`admin_repository.dart:80,100`) use a hard `.limit(300)` cap rather than true cursor pagination — functionally fine up to 300 rows, then silently truncates.

### 2.6 Firestore security-rules read amplification

`firestore.rules` (1,716 lines) contains **25 `get()` calls and 18 `exists()` calls**, almost entirely for membership/org/project/quote ownership checks (e.g. `membershipDoc`, `orgDoc`, `projectDoc`, `requestDoc`, `supplierApprovedQuoteOwner`). Firestore evaluates security rules **per document returned by a query**, so any `list` query gated by one of these functions incurs one or more *additional billed reads per returned document*, on top of the documents themselves. This roughly doubles the effective read cost of org/contractor-scoped list queries (`watchContractorOrgRequests`, `watchOrgPendingProcurement`, and similar) at any scale — it is reflected in the cost model below as a rules multiplier, not a separate line item.

This is a correct and necessary security design, not a bug — but it is a real, currently-invisible cost multiplier worth knowing about when reading a Firestore bill.

### 2.7 Indexes

`firestore.indexes.json` defines 21 composite indexes. Cross-referencing against the query call sites found:

- 19 of 21 indexes have a clear, exact matching query in the read code (RFQ/quote/catalog/org queries).
- Two indexes — `quoteRequests (customerId, createdAt desc)` and `quoteRequests (status, createdAt desc)` — have **no exact matching query** in the repository code reviewed (customer/admin list queries in the codebase sort client-side or filter on different fields). These may back a screen not covered in this pass (e.g. `access_request_repository.dart` wasn't read in full) — **do not delete without confirming via the Firebase console's per-index usage metrics first.** If genuinely unused, each costs extra write-side overhead (every matching document write also updates the index) for zero read benefit.
- No missing-index risk was found: every `where`+`where`/`orderBy` combination located in the read code has either a matching composite index or needs only Firestore's automatic single-field index.

### 2.8 Large documents / repeated downloads

- RFQ and quote line items are embedded arrays inside the parent document rather than subcollections. At current usage (tens of items per RFQ) this is efficient (single read gets the whole RFQ); it would only become a concern if item counts grew into the hundreds+ per RFQ, which is not the current pattern.
- Storage usage is minimal and low-risk: the only Storage-backed content is **read-only catalog product images**, populated by an offline import tool, not user uploads (`storage.rules` denies all writes except catalog import tooling; no RFQ attachments or quote PDFs exist in the app). Download URLs are resolved once and cached in an in-memory map (`catalog_image_url.dart:16,68-100`), so the same image's URL isn't repeatedly recomputed.
- No repeated-download pattern was found for Firestore documents — listeners deliver deltas, not full re-downloads, after the initial attach.

### 2.9 Cloud Functions

None are deployed. All cross-document consistency logic that would typically live in a Firestore trigger (marking competing quotes "not selected," marking outdated quotes, audit logging) currently runs **client-side inside batches/transactions**. This is a reliability/consistency design note, not a current cost item — Cloud Functions cost is $0 today. If this logic is later migrated to triggers, it would add Cloud Functions invocation cost on top of (not instead of) current Firestore costs.

### 2.10 Hosting

`firebase.json` serves the Flutter web build (`build/web`) with a single SPA rewrite rule and no custom `headers`/cache-control tuning — Firebase Hosting's default long-cache-by-hash behavior for build assets applies. No compression or web-renderer configuration is visible in the repo to confirm bundle size; Flutter web builds are typically several MB and are the main driver of the (modest) hosting bandwidth cost in §4.

### 2.11 Analytics / Crashlytics

Firebase Analytics is deliberately narrow and flag-gated: a fixed whitelist of ~16 named business events (`lib/analytics/app_analytics.dart:11-27`), explicitly documented to exclude free text/PII. No per-render or loop-driven event logging was found. A second catalog-specific analytics sink exists (`lib/analytics/catalog_rfq_analytics.dart`) with the same low-volume, discrete-event pattern. Crashlytics is excluded on web (no web SDK) and used normally on mobile. **Both are free regardless of volume under Firebase's standard pricing** — not a cost driver at any scale modeled here.

### 2.12 Auth

Email/password only, via `firebase_auth`. One custom claim (`platformAdmin`) checked in rules. `watchAuthSession` re-fetches the ID token on every `users/{uid}` document change, which is a network round trip but not a billed Firestore or Auth cost. Firebase Authentication is free for email/password at any MAU scale modeled here.

---

## 3. Cost modeling assumptions

All figures below are **order-of-magnitude illustrations**, not billing predictions. They exist to show *how* cost scales with company count, particularly to surface the super-linear term identified in §2.1. Actual usage will depend on real user behavior; verify current unit prices at firebase.google.com/pricing before budgeting.

Per-company assumptions (illustrative, held constant across all scale tiers):
- 4 users/company; 60% of companies are contractors, 40% suppliers.
- 30% of users are active on a given business day (22 business days/month).
- Each contractor company creates ~8 RFQs/month; each RFQ stays "open" ~1.5 months on average; each RFQ receives quotes from ~3 suppliers.
- Unit prices used: Firestore reads $0.06/100K, writes $0.18/100K, storage $0.18/GiB-month; Firebase Storage $0.026/GiB stored + $0.12/GiB egress; Hosting $0.15/GiB egress beyond the 10GiB/month free tier. Auth, Functions (none deployed), Analytics, Crashlytics: $0 at every scale modeled.

Reads are split into two components that behave very differently as the company count (N) grows:

- **Linear component (A):** listeners and one-time reads scoped to a user's own company/projects/orders (§2.1 table, minus the marketplace broadcast row). Scales as O(N).
- **Quadratic component (B):** the `openToAllSuppliers` marketplace-wide listener (§2.1). Both the matched-document count and the number of concurrently-subscribed supplier sessions grow with N, so this component scales as O(N²). The ~1.6-1.8× security-rules read multiplier (§2.6) is folded into both components below.

---

## 4. Estimated monthly cost by company count

| Companies (N) | Firestore reads (est./mo) | Firestore writes (est./mo) | Firestore storage | Firestore $/mo | Storage (files) $/mo | Hosting $/mo | Auth / Functions / Analytics / Crashlytics | **Total $/mo (approx.)** |
|---:|---:|---:|---:|---:|---:|---:|---|---:|
| 10 | ~145K | ~1.5K | ~0.1 GB | ~$0.11 | ~$0.05 | $0 (within free tier) | $0 | **≈ $0.2 / mo** (within free tier) |
| 100 | ~5.0M | ~15K | ~1 GB | ~$3.2 | ~$0.20 | $0 (within free tier) | $0 | **≈ $3.4 / mo** |
| 500 | ~103M | ~75K | ~5 GB | ~$62.7 | ~$0.97 | ~$3.9 | $0 | **≈ $67 / mo** |
| 1,000 | ~401M | ~150K | ~10 GB | ~$242 | ~$1.9 | ~$9.3 | $0 | **≈ $253 / mo** |
| 10,000 | **~39.1B** | ~1.5M | ~100 GB | **~$23,464** | ~$14.5 | ~$107 | $0 | **≈ $23,600 / mo** |

Read the 10,000-company row as a warning, not a forecast: it shows what happens if the current `openToAllSuppliers` broadcast-listener pattern (§2.1) is left unchanged while the platform scales two orders of magnitude — read volume grows ~270x faster than company count between the 1,000 and 10,000 rows (400M → 39.1B), whereas every other line item grows roughly proportionally with N. In practice the system would hit Firestore per-project quota limits and severe client-side listener/memory pressure long before reaching this point — which is itself the argument for fixing the pattern before it needs to.

For contrast, if the marketplace-wide listener were bounded the same way the rest of the app already bounds its data (§5, recommendation 1), the 10,000-company row's read cost would fall back to roughly the linear trend (~$1,000-1,500/mo range) instead of ~$23,600/mo.

---

## 5. Recommendations (all preserve existing functionality — no behavior change for end users)

1. **Bound the marketplace-wide supplier listener.** Add a `.limit()` (e.g. most-recent 200 open RFQs) and/or a recency filter (e.g. `createdAt` within the last N days) to the `openToAllSuppliers` query in `watchIncomingRequestsForSupplier` (`request_repository.dart:191-204`), with existing UI pagination/"load more" for anything older. This is the single highest-leverage fix — it directly targets the O(N²) term in §4. Needs product sign-off on the recency window since it changes which very-old open RFQs a supplier sees live vs. on-demand.
2. **Share the duplicate `watchCustomerReceivedQuotes` listeners.** Consolidate `customerReceivedQuotesProvider`, `quoteCountByRequestProvider`, and `unreadQuoteCountByRequestProvider` (`providers.dart:129-177`) onto a single underlying stream, deriving counts client-side instead of opening 3 identical Firestore listeners.
3. **Replace full-collection "mark seen" scans with a cursor.** Track a `lastSeenAt` timestamp (or a maintained unseen-count field updated transactionally at write time) instead of re-scanning the customer's/supplier's entire history on every dashboard visit (`quote_service.dart:860-1039`).
4. **Confirm and prune unused indexes.** Check the Firebase console's per-index usage stats for `quoteRequests (customerId, createdAt desc)` and `quoteRequests (status, createdAt desc)` (§2.7) before removing — if confirmed unused, removing them eliminates write-side overhead with zero read-side impact.
5. **Add a Firestore TTL policy on `auditEvents`.** Firestore's native TTL feature (no code change, no functionality change) can auto-expire audit records after a defined retention window, capping the one collection with unbounded write-only growth (§2.1 write-amplification note).
6. **Re-check `watchAccessibleProjects`'s per-org/per-project listener fan-out** (`project_repository.dart:91-362`) against its collection-group fallback — if the fallback already covers the same data, the per-org and per-project listeners may be redundant for most users, reducing concurrent listener count without changing what a user sees.

None of these were implemented as part of this review, since each needs a scoping/product decision (recency windows, retention periods, or confirmation of index usage) before being safe to ship. This report itself is the only artifact being committed.
