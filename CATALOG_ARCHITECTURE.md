# Construction RFQ — Catalog Architecture

**Role:** Catalog Architecture Lead  
**Status:** Planning only (no production code in this document)  
**App:** Existing Flutter/Firebase Construction RFQ (`construction_rfq`)  
**Principle:** Catalog supports accurate RFQ line items; it does not replace the quote/tender/order workflow.

---

## 1. Executive summary

The app today ships a **52-item Hebrew seed catalog** loaded entirely into memory with client-side search. A **production dataset** already exists locally:

| Entity | Count | Source path |
|--------|------:|-------------|
| Categories (flat/tree) | 418 | `/Users/itayamar/catalog-working/normalized/categories.flat.json` |
| Products | 11,149 | `.../normalized/products.jsonl` |
| Variants | 31,551 | `.../normalized/variants.jsonl` |
| Catalog products (subset) | 2,780 | `.../normalized/catalogProducts.jsonl` |
| Supplier items | 1,372 | `.../normalized/supplierItems.jsonl` |
| Image map + files | 13,557 | `.../assets/image-map.json`, `.../assets/images/` |

This document defines how to embed that catalog **inside the existing app** without redesigning RFQ business flows, route names, or Firestore security for quotes/users.

---

## 2. Current state (project scan)

### 2.1 Product model (today)

**File:** `lib/models/product.dart`

| Field | Type | Notes |
|-------|------|--------|
| `id` | String | Doc id |
| `name`, `category`, `variant`, `unitType` | String | Single flat category string |
| `unitsPerPackage`, `boxesCount`, `litersPerBucket` | optional | Packaging hints |
| `description` | String | Plain text |
| `imageUrl` | String? | Unused in seed (always null) |
| `brand`, `sku` | String | Added in V3 Phase 2 |
| `specs` | Map | Key/value |
| `packagingLabel`, `relatedProductIds` | optional | UI helpers |

**Gaps vs real dataset:** No `categoryIds[]`, no variant entity, no `aka` aliases, no HTML attributes, no `isActive`, no `size` object, no supplier-item linkage, integer source IDs vs string doc ids.

### 2.2 Related RFQ models (unchanged by catalog)

| Model | File | Catalog touchpoint |
|-------|------|-------------------|
| `CartItem` | `lib/models/cart_item.dart` | Holds `Product` + `quantity` |
| `QuoteRequestItem` | `lib/models/quote_request_item.dart` | **Snapshot** at submit: `productId`, `productName`, `category`, `unitType`, `quantity`, `notes` |
| `QuoteRequest` | `lib/models/quote_request.dart` | Embedded `items[]` on Firestore doc |
| `SupplierQuote` / items | `lib/models/supplier_quote.dart` | Priced by supplier; not catalog-priced |

**RFQ flow (must stay compatible):**

```
/catalog → /product/:id → cartProvider → /cart → submitQuoteRequest
         → /request-confirmation?id=
```

Duplicate flow: `quote_compare` → load items by `productId` → `cartProvider` + `rfqPrefillProvider` → `/cart`.

Suppliers never browse the full catalog in the current UX; they respond to **frozen line items** on the request.

### 2.3 Firestore collections (today)

**Defined in:** `lib/utils/constants.dart`

| Collection | Used for catalog? | Rules (`firestore.rules`) |
|------------|-------------------|---------------------------|
| `products` | Yes — full collection stream | `read: signed-in`, **`write: false`** |
| `appMeta/seedStatus` | Seed flag only | read signed-in, write false |
| `users`, `quoteRequests`, `supplierQuotes` | RFQ (not catalog) | Existing rules |

**Indexes (`firestore.indexes.json`):** Only `quoteRequests` and `supplierQuotes`. **No product indexes.**

### 2.4 Services & data layer (no repositories)

| Layer | File | Behavior |
|-------|------|----------|
| `ProductService` | `lib/services/product_service.dart` | `watchProducts()` = entire `products` snapshot; `getProduct(id)`; `getCategories()` = scan all docs |
| `SeedService` | `lib/services/seed_service.dart` | Single batch, 52 docs, `productsSeeded` flag |
| `MockStore` | `lib/services/mock_store.dart` | Demo: in-memory list from `getSeedProducts()` |
| `QuoteService` | `lib/services/quote_service.dart` | Maps `CartItem` → `QuoteRequestItem` embedded maps |

**There is no repository abstraction.** Providers call services directly.

### 2.5 Providers & UI

| Provider | File | Role |
|----------|------|------|
| `productsProvider` | `lib/providers/providers.dart` | `StreamProvider<List<Product>>` — all products |
| `productCategoriesProvider` | same | `FutureProvider` — distinct categories |
| `catalogScrollControllerProvider` | same | Scroll retention |
| `cartProvider` | `lib/providers/cart_provider.dart` | In-memory cart |
| `rfqPrefillProvider` | `lib/providers/rfq_prefill_provider.dart` | Duplicate-request prefill |

| Screen | Route | Catalog behavior |
|--------|-------|------------------|
| `ProductCatalogScreen` | `/catalog` | Client filter: search, category chip, brand chip |
| `ProductDetailScreen` | `/product/:id` | `getProduct`; related ids |
| `CartScreen` | `/cart` | Submit RFQ |
| `EditRequestScreen` | `/edit-request/:id` | Edits snapshot items only |

### 2.6 App modes

**File:** `lib/config/app_mode.dart`

- **Firebase:** `products` collection (or empty until seeded).
- **Demo:** `MockStore` + 52 seed products — must remain usable for offline QA with a **representative slice** of real data after migration.

### 2.7 Source dataset schema (normalized)

**Product (JSONL)** — key fields:

- `id` (int), `name`, `aka` (string[]), `isActive` (bool)
- `categoryIds` (int[]), multi-category
- `attributes` ([{attribute, description HTML}])
- `size`, `displaySize`, `primaryImage` (local path)
- `variants` (embedded array with `id`, `name`, `color`, `size`, `status`, `image`)
- `images`, `catalogEntries`, `supplierItems` (references)

**Variant (JSONL):**

- `id`, `name`, `color`, `image`, `size`, `status`, `productIds[]`, `supplierItems`

**Category (flat/tree):**

- `id`, `name`, `parentId`, `hasProducts`, nested `children`

**Image map:**

- `source_url_hash`, `local_file`, `sha256`, `size_bytes`

---

## 3. Design goals & constraints

### Goals

1. **Production scale:** 11k products, 31k variants, 418 categories — bounded reads, fast search, RTL Hebrew UI unchanged.
2. **RFQ accuracy:** Customer selects **product + variant + quantity**; submitted request stores a **stable snapshot** (existing `QuoteRequestItem` shape + optional extensions).
3. **Backward compatibility:** Old requests/quotes keep working; legacy `Product` fields remain populated for demo and gradual client upgrade.
4. **Firebase-first:** Catalog writes via **admin import only** (matches `products` write:false).
5. **Images:** Serve from **Firebase Storage** (or CDN) with local path mapping during import.

### Non-goals (explicit)

- Payments, chat, ERP, BOQ upload, supplier catalog editing in app.
- Replacing RFQ/tender/order routes or status Hebrew strings.
- Real-time catalog sync from external Punct/source APIs (import batch only).

---

## 4. Target architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter UI (RTL)                          │
│  CatalogScreen │ CategoryTree │ ProductDetail │ VariantPicker     │
│  Cart / RFQ (unchanged workflow)                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ Riverpod
┌────────────────────────────▼────────────────────────────────────┐
│  CatalogController providers (paged list, search, category)      │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│  CatalogRepository (interface)                                   │
│    ├─ FirestoreCatalogRepository (prod)                          │
│    └─ LocalCatalogRepository (demo / asset bundle slice)           │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
   Firestore            Firebase Storage      Search index
   (products,           (images)              (Firestore tokens
    categories,                               or Algolia — Phase 2)
    variants,
    catalogMeta)
```

**RFQ boundary:** `QuoteService.submitQuoteRequest` continues to accept cart lines; repository returns `CatalogSelection` mapped to existing `CartItem` / `QuoteRequestItem` fields.

---

## 5. Firestore collections

### 5.1 `catalogMeta` (document: `current`)

| Field | Type | Purpose |
|-------|------|---------|
| `version` | string | e.g. `2026-06-03-normalized` |
| `productCount`, `variantCount`, `categoryCount` | int | Integrity |
| `importedAt` | timestamp | |
| `imageBasePath` | string | Storage prefix |
| `searchMode` | string | `firestore` \| `algolia` |

Replaces overloading `appMeta/seedStatus` for production catalog.

### 5.2 `categories` (418 docs)

**Doc id:** `{categoryId}` as string (from source int).

| Field | Type | Index |
|-------|------|-------|
| `name` | string | |
| `nameLower` | string | prefix search helper |
| `parentId` | string? | |
| `pathIds` | string[] | Breadcrumb: root → leaf |
| `pathNames` | string[] | Hebrew breadcrumb display |
| `depth` | int | |
| `hasProducts` | bool | |
| `sortOrder` | int | Sibling order |
| `productCount` | int | Denormalized (optional) |
| `isActive` | bool | default true |

**Queries:**

- Roots: `parentId == null` + `orderBy sortOrder`
- Children: `parentId == {id}`

No need to download all 418 at once on mobile: cache tree in memory after one collection read (small).

### 5.3 `products` (11,149 docs)

**Doc id:** `{productId}` string (source int as string, e.g. `"11"`).

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | |
| `nameLower` | string | Search |
| `aka` | string[] | Aliases (max 20) |
| `searchTokens` | string[] | Normalized tokens for array-contains (cap ~30) |
| `categoryIds` | string[] | Multi-category |
| `primaryCategoryId` | string | For list card subtitle |
| `categoryPathNames` | string[] | Denormalized display |
| `brand` | string? | Extracted if available |
| `sku` | string? | Optional |
| `unitType` | string | Mapped from `size.unit` |
| `packagingLabel` | string? | Human-readable |
| `descriptionPlain` | string | Stripped HTML (≤2k) |
| `descriptionHtml` | string? | Optional; detail only |
| `specs` | map | Flattened from attributes |
| `isActive` | bool | Filter default true |
| `variantCount` | int | |
| `defaultVariantId` | string? | Cheapest or first active |
| `imageUrl` | string? | Storage HTTPS URL |
| `imageThumbUrl` | string? | 200px variant |
| `relatedProductIds` | string[] | Same category / manual |
| **Legacy compat** | | |
| `category` | string | `primaryCategoryId` name |
| `variant` | string | Default variant label |
| `updatedAt` | timestamp | |

**Do not embed 31k variants inside product docs** (doc size / read cost).

### 5.4 `productVariants` (31,551 docs)

**Option A (recommended):** Top-level collection `productVariants` with field `productId`.

| Field | Type |
|-------|------|
| `productId` | string |
| `name` | string |
| `nameLower` | string |
| `color` | string? |
| `sizeLabel` | string | From `size` object |
| `status` | string | `Active` / inactive |
| `imageUrl`, `imageThumbUrl` | string? |
| `sortOrder` | int |
| `legacyKey` | string? | For cart snapshot |

**Queries:** `productId == X` + `status == Active` + `orderBy sortOrder` (composite index).

**Option B:** Subcollection `products/{id}/variants` — simpler security rules inheritance, more reads for list endpoints. Use if variant rules must differ.

### 5.5 `supplierItems` (optional Phase 3)

**Collection:** `catalogSupplierItems` (1,372 docs) — reference data for manufacturer/SKU hints, **not** customer-facing prices in RFQ MVP.

| Field | Type |
|-------|------|
| `productId`, `variantIds` | string / string[] |
| `manufacturer`, `supplier`, `name` | string |
| `status` | string |

Keep **out of customer cart** until product explicitly needs supplier SKU display.

### 5.6 Existing collections (unchanged)

- `quoteRequests`, `supplierQuotes`, `users` — no schema change required for catalog MVP.
- Optional future: extend embedded `items[]` with `variantId`, `variantName`, `imageUrl` (backward compatible: old clients ignore extra keys).

### 5.7 Security rules (additions)

```text
categories/{id}     → read: signed-in; write: false
productVariants/{id}→ read: signed-in; write: false
catalogMeta/{id}    → read: signed-in; write: false
products/{id}       → read: signed-in; write: false (unchanged)
```

Storage rules: public read for `catalog/images/**` thumbs; optional auth for full size.

### 5.8 Composite indexes (new)

Add to `firestore.indexes.json`:

1. `products`: `isActive` ASC, `primaryCategoryId` ASC, `nameLower` ASC  
2. `products`: `isActive` ASC, `searchTokens` ARRAY_CONTAINS, `nameLower` ASC  
3. `productVariants`: `productId` ASC, `status` ASC, `sortOrder` ASC  
4. `categories`: `parentId` ASC, `sortOrder` ASC  

---

## 6. Domain models (Dart)

### 6.1 New models (catalog domain)

| Model | Responsibility |
|-------|----------------|
| `CatalogCategory` | Tree node, breadcrumbs |
| `CatalogProduct` | List + detail summary (no variant list embedded) |
| `CatalogVariant` | Selectable SKU for cart |
| `CatalogProductDetail` | Product + variants + specs |
| `CatalogSearchQuery` | text, categoryId, filters, page cursor |
| `CatalogPage<T>` | items + `nextCursor` + `hasMore` |
| `CatalogSelection` | productId, variantId, display fields for RFQ snapshot |

### 6.2 Mapping to legacy `Product` (compatibility)

`CatalogProduct.toLegacyProduct()` populates existing `Product` fields so **cart, product card, and providers** can migrate incrementally:

| Legacy field | Source |
|--------------|--------|
| `id` | `productId` |
| `name` | product name |
| `category` | `categoryPathNames.last` or primary category name |
| `variant` | selected variant `name` or default |
| `unitType` | mapped unit |
| `description` | `descriptionPlain` |
| `imageUrl` | thumb URL |
| `sku`, `brand`, `specs`, `packagingLabel` | direct |

### 6.3 Cart & RFQ snapshot extension (backward compatible)

**`CartItem` (Phase 2):** add optional `variantId`, `variantName`, `imageUrl` — defaults null for old code.

**`QuoteRequestItem.toEmbeddedMap()` (Phase 2):** add optional keys:

- `variantId`, `variantName`, `productImageUrl`

Old supplier screens continue to use `productName` + `quantity`; new fields are additive.

---

## 7. Repository layer

Introduce **`CatalogRepository`** interface (first catalog-specific repository in the app):

```dart
abstract class CatalogRepository {
  Stream<CatalogMeta> watchMeta();
  Future<List<CatalogCategory>> getCategoryTree();
  Future<CatalogPage<CatalogProduct>> listProducts(CatalogListQuery q);
  Future<CatalogProductDetail?> getProductDetail(String productId);
  Future<CatalogPage<CatalogProduct>> search(CatalogSearchQuery q);
}
```

### Implementations

| Implementation | When | Data source |
|----------------|------|-------------|
| `FirestoreCatalogRepository` | `AppMode.useFirebase` | Firestore + Storage URLs |
| `AssetCatalogRepository` | Demo / CI | Bundled JSON slice (~200 products) under `assets/catalog/` |
| `HybridCatalogRepository` | Dev | Firebase with fallback slice |

**`ProductService` becomes a thin facade** delegating to `CatalogRepository` and mapping to `Product` until UI migrates off legacy type.

**`MockStore`** stops owning 52 hardcoded products; demo uses `AssetCatalogRepository` or prebuilt Firestore emulator seed.

---

## 8. Services

| Service | Role |
|---------|------|
| `CatalogRepository` | All catalog reads |
| `CatalogImageResolver` | thumb vs full URL, placeholder |
| `CatalogSearchService` | Tokenization, debounce, query building (if not in repo) |
| `QuoteService` | **Unchanged contract**; accepts `CartItem` / `CatalogSelection` mapper |
| `SeedService` | **Deprecated for 11k**; keep only for dev 52-item quick seed flag OR remove after Phase 4 |

### Import services (outside Flutter app — `tool/` or `scripts/`)

| Tool | Runtime | Purpose |
|------|---------|---------|
| `catalog_import.dart` / `import_catalog.mjs` | Admin SDK | ETL JSONL → Firestore batches (500/write) |
| `catalog_upload_images.dart` | Admin SDK | Local `assets/images` → Storage + URL map |
| `catalog_verify.dart` | CLI | Counts, orphan variants, broken image URLs |

**Never import from the mobile client** (rules block writes).

---

## 9. Search architecture

### Phase 1 — Firestore-native (recommended MVP)

**Problem:** 11k full scans are unacceptable on mobile and costly on billing.

**Approach:**

1. **Category-first navigation** — user picks leaf category → paged query `primaryCategoryId + isActive + orderBy nameLower` (page size 24).
2. **Prefix search on `nameLower`** — Firestore range query `>= query` and `< query + '\uf8ff'` scoped to `primaryCategoryId` when category selected.
3. **`searchTokens` array-contains** — import pipeline tokenizes `name + aka` (Hebrew normalized, niqqud stripped, digits kept); max 30 tokens per product; query uses single token for broad match, client ranks top 50.
4. **Client refinement** — secondary filter on brand/SKU within loaded page only.

**Limitations:** No fuzzy typo tolerance; acceptable for construction material names (often exact).

**Debounce:** 300ms in `CatalogSearchController`; cancel in-flight requests.

### Phase 2 — Dedicated search (optional)

If token search insufficient:

- **Algolia** or **Typesense** index: `productId`, `name`, `aka`, `categoryPath`, `variantNames[]`, `imageThumbUrl`.
- Sync on import via Cloud Function or batch indexer.
- Flutter: `search_products` Cloud Function proxy (keeps API keys off client).

**Decision gate:** Phase 1 metrics — p95 search latency & zero-result rate after 2 weeks internal QA.

### Category browse

- Load full category tree once (418 nodes ≈ small JSON), cache in `Riverpod` `categoryTreeProvider` with 24h TTL in `shared_preferences` + `catalogMeta.version` invalidation.
- UI: collapsible tree or drill-down chips (RTL), not 418 flat chips.

---

## 10. Image architecture

### 10.1 Import pipeline

```
local_file (catalog-working/assets/images/*.webp)
    → Admin upload to Firebase Storage
    → Path: catalog/images/{sha256_prefix}/{filename}.webp
    → Generate thumb: catalog/thumbs/{id}_200.webp (Cloud Function or sharp in script)
    → Write imageUrl + imageThumbUrl on product / variant docs
```

Use existing `image-map.json` (`local_file`, `sha256`) for dedup and skip re-upload.

### 10.2 Client loading

| Context | URL | Widget |
|---------|-----|--------|
| List card | `imageThumbUrl` | `CachedNetworkImage`, fixed 48×48, placeholder icon |
| Detail hero | `imageUrl` | Cached, progressive |
| Variant picker | variant `imageThumbUrl` | Row thumbnail |

**Fallback:** `BrandLogo`-style placeholder (no broken image icon).

**Demo mode:** Bundle ~50 thumbs in `assets/catalog/thumbs/` or map to static Firebase URLs in metadata.

### 10.3 Storage rules

- Read: public (or signed-in only if cost/abuse concern).
- Write: admin only.

### 10.4 Size & format

- Keep **WebP** from source; Flutter supports via `cached_network_image`.
- Target thumb **≤15 KB**; full **≤120 KB** where possible.

---

## 11. Migration strategy

### 11.1 ID strategy

| Source | Firestore doc id |
|--------|------------------|
| Product `id: 11` | `"11"` |
| Variant `id: 24572` | `"24572"` |
| Category `id: 7` | `"7"` |

Preserve string ids in `QuoteRequestItem.productId` for new requests. Old seed ids (`p001`) coexist until seed collection cleared — **import to fresh Firebase project** or **delete `products` + reimport** in dev.

### 11.2 ETL mapping (summary)

| Source | Target |
|--------|--------|
| `products.jsonl` | `products` + extract default variant |
| `variants.jsonl` | `productVariants` |
| `categories.flat.json` | `categories` + compute `pathIds` / `pathNames` |
| `attributes[].description` HTML | `descriptionPlain` + optional `descriptionHtml` |
| `size` | `unitType`, `packagingLabel` |
| `primaryImage` local path | Storage upload → `imageUrl` |
| `categoryIds[]` | `categoryIds` + denormalized paths |
| `isActive == false` | `isActive: false` (excluded from default queries) |

### 11.3 Import execution

1. **Staging project** — full import + QA.
2. **Verify** — counts match `CATALOG_READY_REPORT.md`, spot-check 50 products, image 404 rate <1%.
3. **Production** — maintenance window; import; set `catalogMeta/current`.
4. **App release** — requires new client (repository + paged UI); old app still reads `products` if legacy fields populated.

**Batching:** 500 writes per batch; ~23 batches products, ~64 batches variants, ~1 batch categories.

### 11.4 Backward compatibility

| Concern | Mitigation |
|---------|------------|
| Old RFQs with `p001` ids | Historical data unchanged; no migration |
| Old app on new Firestore | Legacy fields `category`, `variant` on each product doc |
| Demo mode | Asset slice + same repository interface |
| `SeedService` 52 products | Disable when `catalogMeta.version` present |

### 11.5 Rollback

- Keep `catalog-working/` backup zip.
- Firestore export before import.
- `catalogMeta.version` pin to previous import manifest.

---

## 12. UI / provider changes (planned, not implemented)

| Area | Change |
|------|--------|
| `ProductCatalogScreen` | Category tree drawer + paged list + search debounce |
| `ProductDetailScreen` | Variant selector (required if `variantCount > 1`) |
| `ProductCard` | Thumb from network |
| Providers | Replace `productsProvider` stream-all with `catalogProductsPageProvider` |
| Routes | **Keep** `/catalog`, `/product/:id`, `/cart` |

---

## 13. Implementation phases

### Phase 0 — Foundations (1 week)

- [ ] Approve this document and ID/field naming.
- [ ] Add `catalogMeta` + `categories` + `productVariants` rules and indexes to repo.
- [ ] Define Dart models (`CatalogProduct`, `CatalogVariant`, `CatalogCategory`) — **no UI yet**.
- [ ] Add `tool/catalog_import` spec (CLI arguments, env, dry-run).

**Exit:** Emulator empty collections created; indexes deploy without error.

---

### Phase 1 — Import pipeline (2 weeks)

- [ ] Build admin import CLI from `catalog-working/normalized/*.jsonl`.
- [ ] Generate `searchTokens`, `nameLower`, category paths.
- [ ] Import 418 categories + 11,149 products + 31,551 variants to staging.
- [ ] Upload 13,557 images to Storage; attach URLs.
- [ ] Verification report (counts, orphans, missing images).
- [ ] Populate **legacy compat fields** on `products`.

**Exit:** Staging Firestore matches source counts; 95% images resolve in browser.

---

### Phase 2 — Repository & search MVP (2 weeks)

- [ ] Implement `CatalogRepository` + `FirestoreCatalogRepository`.
- [ ] Paged `listProducts` + category filter + token search.
- [ ] `categoryTreeProvider` with version cache.
- [ ] Refactor `ProductService` to delegate; map to legacy `Product`.
- [ ] Demo `AssetCatalogRepository` (200-product slice).

**Exit:** Integration tests against emulator; paged catalog API <200ms p95 per page.

---

### Phase 3 — Flutter UI integration (2 weeks)

- [ ] Catalog screen: tree + infinite scroll + search bar.
- [ ] Product detail: variant picker, specs HTML render (sanitized), images.
- [ ] Cart: store `variantId` in `CartItem`; snapshot in `QuoteRequestItem`.
- [ ] Duplicate-request flow resolves new ids.
- [ ] Keep RTL + compact premium components (`AppListCard`, `LoadingView`, `EmptyState`).

**Exit:** E2E: browse → select variant → cart → submit RFQ → supplier sees line items.

---

### Phase 4 — Production cutover & cleanup (1 week)

- [ ] Production import + `catalogMeta` flag.
- [ ] Disable legacy `SeedService` full-catalog seed.
- [ ] Monitor Firestore read units and Storage bandwidth.
- [ ] Remove client-side full-catalog filter (`_filterProducts` on 11k list).
- [ ] Documentation for re-import procedure.

**Exit:** Tag release (e.g. `v4.0-catalog`); QA checklist signed.

---

### Phase 5 — Enhancements (optional)

- [ ] Algolia/Typesense if search quality insufficient.
- [ ] `catalogSupplierItems` for manufacturer hints on detail.
- [ ] Related products graph from `categoryIds` + co-occurrence.
- [ ] Cloud Function: incremental delta import.
- [ ] Supplier read-only catalog view (separate story; not RFQ MVP).

---

## 14. QA checklist (post-implementation)

- [ ] Category tree loads <500ms (cached).
- [ ] First catalog page loads <1s on 4G.
- [ ] Search returns results for Hebrew aliases (`aka`).
- [ ] Product with 10+ variants — all selectable.
- [ ] Cart + submit RFQ — supplier sees correct names/quantities.
- [ ] Duplicate request — cart prefilled with resolvable ids.
- [ ] Demo mode works offline with asset slice.
- [ ] Old RFQ documents still open without error.
- [ ] Firestore rules: client cannot write catalog.
- [ ] Image broken rate <1% on random 100 products.

---

## 15. Risks & mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Full-collection reads left in code | Cost + OOM | Delete `watchProducts().snapshots()` all-docs path in Phase 2 |
| Firestore search limitations | Poor UX | Category-first + token arrays; Phase 5 Algolia |
| Large HTML descriptions | Doc size | Store plain in list docs; HTML only in detail fetch |
| Variant/doc count | Index build time | Staged import; monitor quotas |
| Image upload time | Delayed go-live | Parallel upload workers; resume by `sha256` |
| ID change breaks old carts | Low | New string ids only for new requests |

---

## 16. File map (planned additions)

```text
construction_rfq/
  CATALOG_ARCHITECTURE.md          ← this document
  lib/
    models/catalog/                ← CatalogProduct, CatalogVariant, ...
    repositories/
      catalog_repository.dart
      firestore_catalog_repository.dart
      asset_catalog_repository.dart
    services/
      catalog_image_resolver.dart
    providers/
      catalog_providers.dart
  tool/
    catalog_import/
    catalog_upload_images/
  firestore.rules                  ← categories, productVariants
  firestore.indexes.json           ← product indexes
  assets/catalog/                  ← demo slice only (optional)
```

**Existing files to modify (later phases):**  
`product_service.dart`, `product_catalog_screen.dart`, `product_detail_screen.dart`, `cart_item.dart`, `quote_request_item.dart`, `providers.dart`, `mock_store.dart`, `seed_service.dart`.

---

## 17. References

| Resource | Path |
|----------|------|
| App constants | `lib/utils/constants.dart` |
| Current product model | `lib/models/product.dart` |
| Product service | `lib/services/product_service.dart` |
| Seed data (52) | `lib/data/seed_products.dart` |
| Normalized catalog | `/Users/itayamar/catalog-working/normalized/` |
| Catalog readiness report | `/Users/itayamar/CATALOG_READY_REPORT.md` |
| Router (catalog routes) | `lib/router/app_router.dart` |

---

*End of architecture document. No production application code is included by design.*
