# Catalog search foundation (Phase 4)

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

**Re-import required** after Phase 4 to populate new variant fields in emulator/production catalog collections. Until then, search falls back to `nameLower` defaults from existing documents.

## Phase 4.5 — Search field verification

| Check | Command / artifact |
|-------|-------------------|
| Full dry-run + search fields | `CATALOG_DATA_ROOT=/Users/itayamar/catalog-working flutter test test/catalog_full_dry_run_test.dart` |
| Emulator gate (rollback → import → verify) | `./tools/catalog_import/run_emulator_gate.sh` |
| Search smoke (VM-safe REST) | Included in `./tools/catalog_import/run_emulator_gate.sh` (same `emulators:exec` session) |

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

Emulator verification: `tools/catalog_import/out/emulator_verification/summary.json` → `searchFields` block (after re-import with Phase 4 enrich).

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

## Backward compatibility

- Legacy `products` + `ProductService` unchanged.
- Existing catalog screens unchanged.
- RFQ flow unchanged.
- `CatalogRepository` (product listing) unchanged.

## Next steps (Phase 5+)

- Wire search repository to new catalog picker UI.
- Re-run emulator gate after re-import to refresh variant search fields.
- Evaluate external search when Firestore MVP hits relevance/latency limits.
