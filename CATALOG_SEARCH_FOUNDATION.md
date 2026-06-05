# Catalog search foundation (Phase 4) — **PASS** (Phase 4.5 verified 2026-06-04)

Construction RFQ catalog search is **variant-centric**: engineers select purchasable variants when building RFQs, not abstract parent products. Phase 4 adds a **search/query layer only** — no catalog UI cutover, no legacy `ProductService` changes.

## Architecture

```
CatalogSearchRepository (abstract)
├── FirestoreCatalogSearchRepository   ← production MVP
└── MemoryCatalogSearchRepository      ← unit tests
```

**Models:** `CatalogSearchQuery`, `CatalogSearchPage`, `CatalogSearchHit`, `CatalogSearchResult` (loading/error/success for future UI).

**Riverpod:** `catalogSearchRepositoryProvider` — not wired to screens yet.

## Firestore MVP

| Operation | Strategy | Notes |
|-----------|----------|--------|
| Category browse | `categoryIds` array-contains + `isActive` + `sortOrder` / `displayNameLower` | Paginated `limit+1` |
| Text search | `searchTokens` array-contains (best token) + order | One array-contains per query |
| Prefix fallback | `displayNameLower` range | When token too short |
| SKU-like input | `skuLower` prefix range | Alphanumeric short queries |

**Does not** load 31,551 variants into memory. Each request fetches at most `limit` (max 50) documents plus one extra for `hasMore`.

### Search fields on `catalogVariants`

Generated at import by `CatalogVariantSearchFields.enrich()`:

| Field | Purpose |
|-------|---------|
| `nameLower` | Variant name prefix |
| `displayNameLower` | Product + variant label prefix |
| `skuLower` | Denormalized product SKU prefix |
| `categoryIds` | Category filter (from product) |
| `primaryCategoryId` | Primary navigation |
| `categoryPathText` | Breadcrumb text / token source |
| `searchTokens` | Normalized token index |
| `searchAliases` | AKA, color, size labels |
| `isActive` | Indexed boolean for queries |

**Re-import required** after Phase 4 to populate new variant fields in emulator/production catalog collections. **Done** — emulator gate PASS with `searchFields.passed: true` on 31,551 variants.

## Phase 4.5 — Search field verification (**PASS**)

| Check | Result |
|-------|--------|
| Full dry-run search fields | **PASS** (31,551 variants) |
| Emulator import + verify | **PASS** (418 / 11,149 / 31,551) |
| Search smoke (REST, sequential) | **PASS** (163s gate, Terminal.app) |

| Command / artifact | Purpose |
|--------------------|---------|
| `./tools/catalog_import/run_emulator_gate.sh` | Rollback → import → verify → smoke (one session) |
| `tools/catalog_import/out/emulator_verification/summary.json` | Counts + `searchFields` block |
| `flutter test test/catalog_full_dry_run_test.dart` | Dry-run search field check |

**Phase 4.5 Fix:** `flutter test test/catalog_search_emulator_smoke_test.dart` previously called `Firebase.initializeApp()` and failed in VM with `FirebaseCoreHostApi.initializeCore` channel error. Smoke now uses **`EmulatorRestCatalogSearchRepository`** (`:runQuery` over HTTP) — no `cloud_firestore` / FirebaseCore in tests.

| Component | Role |
|-----------|------|
| `EmulatorRestCatalogSearchRepository` | Same `CatalogSearchRepository` contract via REST |
| `CatalogSearchEmulatorSmoke` | Live browse/search/getById checks |
| `FirestoreRestStructuredQueryEncoder` | Builds `:runQuery` JSON from search plans |

`CatalogVariantSearchFieldVerifier` checks **every** variant for:

- `searchTokens` (non-empty list)
- `categoryIds` (list, may be empty for known dataset gaps)
- `isActive`, `nameLower`, `displayNameLower` when `displayName` is set
- `skuLower` when product SKU exists (optional empty)

Dry-run summary: `tools/catalog_import/out/full_dry_run/summary.json` → `searchFields.passed`.

Emulator verification: `tools/catalog_import/out/emulator_verification/summary.json` → `searchFields.passed: true`, `variantsFailed: 0` (gate run 2026-06-04).

Smoke browse uses **categoryId from sampled imported variants**, not category `productCount` / `hasProducts` on category docs.

### Known limitations

- **1,313 products** have empty `categoryIds` → matching variants have `categoryIds: []` (valid; category browse may not list them).
- Firestore text search uses **one** `array-contains` token per query — not full-text relevance.
- SKU prefix search only when `skuLower` was denormalized at import.

## Why variants, not products?

- RFQ line items map to **specific purchasable rows** (size/color/SKU context).
- One product can have many variants; search must surface the row the user will quote.
- Parent `catalogProducts` are loaded **per page** (batch `whereIn` by id) for context only.

## Firestore limitations

- No true full-text search (Hebrew morphology, fuzzy match, ranking).
- Only one `array-contains` per query.
- Compound filters require composite indexes (`firestore.indexes.json`).
- Prefix search is ASCII/Hebrew-normalized, not Google-like relevance.

## Upgrade path (future)

`CatalogSearchRepository` is swappable:

1. **Algolia / Meilisearch / Typesense** — index variants on import; UI keeps same repository interface.
2. **Hybrid** — Firestore browse by category + external engine for text.
3. **Cloud Function** — nightly index build from `catalogVariants`.

Do **not** add external engines in Phase 4.

## Indexes

See `firestore.indexes.json` composite entries for `catalogVariants`:

- `isActive` + `categoryIds` + `sortOrder` / `displayNameLower`
- `isActive` + `searchTokens` + `displayNameLower`
- `isActive` + `displayNameLower` (prefix)
- `isActive` + `skuLower` (prefix)
- `productId` + `isActive` + `sortOrder`

Deploy indexes before relying on category/text search in production:

```bash
firebase deploy --only firestore:indexes
```

## Firestore security (Phase 12)

| Collection | Client read | Client write |
|------------|-------------|--------------|
| `catalogCategories` / `catalogProducts` / `catalogVariants` / `catalogMeta` | Signed-in users | **Denied** |
| `quoteRequests` | Customer + eligible suppliers | Customer create; limited field updates include embedded `items[]` (catalog snapshots) |
| `supplierQuotes` | Customer + supplier | Supplier create; status/seen updates only |

Import uses `firestore.import_emulator.rules` on emulator only — production `firestore.rules` unchanged.

Tests: `test/catalog_firestore_readiness_test.dart`, `test/catalog_emulator_rules_test.dart`.

## Backward compatibility

- Legacy `products` + `ProductService` unchanged.
- Existing catalog screens unchanged.
- RFQ flow unchanged.
- `CatalogRepository` (product listing) unchanged.

## Next steps (Phase 5+)

- Wire search repository to new catalog picker UI.
- Evaluate external search when Firestore MVP hits relevance/latency limits.

## Phase 62 — Full catalog browse + smart search (current)

| Feature | Behavior |
|---------|----------|
| Primary source | **Firestore** `catalogVariants` via `FallbackCatalogSearchRepository` |
| Default browse | First **50** active variants on selector open (no search required) |
| Pagination | `limit+1` cursor tokens; **טען עוד** appends next page |
| Smart search | 300ms debounce; SKU prefix → token → name prefix; category filter |
| Ranking (memory/tests) | exact SKU → token → name prefix |
| Ranking (Firestore) | Index order only — client re-rank not applied across pages |
| Emergency fallback | Demo slice only on query failure or explicit demo mode — **not** on empty category tree alone |

**Provider:** `catalogSearchRepositoryProvider` → Firestore primary, `DemoCatalogSearchData` only in demo mode or after Firestore errors.

## Phase 18 — Selector filters & limits (superseded in part by Phase 62)

| Feature | Status |
|---------|--------|
| Category filter chips | ✅ horizontal browse |
| Active-only (`isActive=true`) | ✅ default in query plan |
| SKU / token priority | ✅ Firestore `skuPrefix` + in-memory rank |
| Search debounce (300ms) | ✅ selector text field |
| Empty-state hints | ✅ manual item fallback copy |
| Default paginated browse | ✅ Phase 62 — 50 per page |
| Algolia / Meilisearch | ❌ deferred |

**Limits:** page size **24** (max 50), paginated `loadMore`. Selector never loads full 31k variant set.
