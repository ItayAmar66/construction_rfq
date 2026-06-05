# Catalog search — production decision pack

## Current state

- `CatalogSearchRepository` abstraction (Firestore MVP)
- Paginated variant search/browse (`effectiveLimit` 24)
- Emulator gate + dry-run import tooling
- No external search SDK

## Options compared

| Option | Pros | Cons | Fit |
|--------|------|------|-----|
| **Firestore fallback (keep)** | Already shipped, rules/indexes ready, no new infra | Token/substring search limits at scale, latency on large catalogs | MVP / small catalog (<50k variants) |
| **Algolia** | Managed, great UX, facets, Hebrew support | Cost, sync pipeline, vendor lock-in | Serious demo + production if budget OK |
| **Typesense** | Self-host or cloud, fast typo-tolerant search | Ops overhead if self-hosted | Production with control + lower SaaS cost |
| **Meilisearch** | Simple API, good DX, open source | Sync job, less enterprise tooling | Mid-size catalog, cost-sensitive |

## Recommendation

**Phase 1 (now):** Keep Firestore as default via `CatalogSearchRepository`.

**Phase 2 (serious demo / production):** Adopt **Typesense Cloud** or **Algolia** behind a new adapter (see Phase 57 skeleton). Reasons:
- Construction SKU + Hebrew token search needs typo tolerance
- Category browse stays paginated; text search offloads to engine
- Firestore remains source of truth; search index is derived read model

**Do not** block RFQ lifecycle on search migration — adapter swap only.

## Migration outline (when chosen)

1. Export `catalogVariants` snapshot (Admin SDK)
2. Build index sync job (CI or Cloud Function — out of scope now)
3. Implement adapter; feature-flag in app config
4. Emulator gate validates parity on sample queries
5. Rollback: flip flag back to Firestore repository

## Non-goals

- No SDK added in this sprint
- No production import/deploy from this doc
