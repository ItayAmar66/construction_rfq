# Catalog admin ops tools (Phase 16)

Debug-only **read-only** visibility into catalog import metadata.

## Route

| Route | Screen | Availability |
|-------|--------|--------------|
| `/dev/catalog-ops` | `CatalogAdminOpsScreen` | `kDebugMode` only |

## Shows

From `catalogMeta/current` via `CatalogAdminOpsService`:

- product / variant / category counts
- `version`, `importedAt`, `searchMode`, `isDemoSlice`
- Warnings (not imported, demo slice, unexpected search mode)

## Quick links (no actions)

- `/dev/catalog-selector` — selector demo
- `./tools/catalog_import/run_emulator_gate.sh`
- `CATALOG_PRODUCTION_DEPLOY_CHECKLIST.md`

## Not included

- No import / delete / write buttons
- No production deploy from UI

## Tests

`test/catalog_admin_ops_test.dart`
