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
