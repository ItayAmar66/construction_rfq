# Catalog performance QA (Phase 20)

Safeguards for **~31k variants** without loading the full catalog in the selector.

## Expected limits

| Setting | Value |
|---------|-------|
| Default page size | **24** |
| Max page size | **50** (`CatalogSearchQuery.effectiveLimit`) |
| Search debounce | **350ms** (selector text field) |
| Category chips shown | up to **40** (UI cap) |

## Architecture guarantees

- Selector uses `CatalogSearchRepository` paginated APIs only — not `CatalogRepository` bulk listing.
- Firestore query plan (`FirestoreCatalogSearchQueryBuilder`) uses indexed filters + `limit+1` pagination.
- `includeInactive: false` by default (active variants only).

## Tests

`test/catalog_performance_qa_test.dart` — paginated browse, query limits, selector state.

Related: `test/catalog_search_filters_test.dart`, `test/catalog_selector_widget_test.dart`.

## Not in scope

- External search engine migration
- Full-catalog in-memory cache
- Production load testing
