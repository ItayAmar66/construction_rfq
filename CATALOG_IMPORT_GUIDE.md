# Catalog import guide

Structured material catalog import for Construction RFQ (not e-commerce). The pipeline supports RFQ material lookup while the legacy `products` collection, `ProductService`, seed products, and RFQ screens remain unchanged until a future cutover.

## Prerequisites

- Normalized dataset at `CATALOG_DATA_ROOT` (default `/Users/itayamar/catalog-working`)
  - `normalized/categories.flat.json` — 418 categories
  - `normalized/products.jsonl` — 11,149 products
  - `normalized/variants.jsonl` — 31,551 variants
  - `assets/image-map.json` — 13,557 image mappings
- Flutter SDK (`flutter pub get`)
- **Firestore emulator** for any write, rollback, or verification

| Variable | Purpose |
|----------|---------|
| `CATALOG_DATA_ROOT` | Working catalog path (normalized + assets) |
| `CATALOG_IMPORT_OUTPUT` | Output dir (default `tools/catalog_import/out`) |
| `FIRESTORE_EMULATOR_HOST` | Required for writes, e.g. `127.0.0.1:8080` |

## Configuration

| File | Use |
|------|-----|
| [tools/catalog_import/config.example.json](tools/catalog_import/config.example.json) | General template (paths, batch size, flags) |
| [tools/catalog_import/config.full_import.emulator.json](tools/catalog_import/config.full_import.emulator.json) | Local-safe full emulator import |

Load JSON config:

```bash
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- \
  --config=tools/catalog_import/config.full_import.emulator.json \
  --import-full --write --emulator
```

CLI flags: `--validate`, `--dry-run`, `--full-dry-run`, `--import-demo`, `--import-full`, `--write`, `--emulator`, `--resume`, `--rollback-catalog`, `--verify-emulator`.

## Collections

| Collection | Doc ID | Notes |
|------------|--------|-------|
| `catalogCategories` | category id | Hierarchical paths |
| `catalogProducts` | product id | RFQ-ready fields + search tokens |
| `catalogVariants` | variant id | Linked via `productId` |
| `catalogMeta` | `current` | Written **last** after successful import |

Security: authenticated read; client writes **denied** in production rules. Full import must use the emulator.

## Commands

### Validate full source (no writes)

```bash
CATALOG_DATA_ROOT=/Users/itayamar/catalog-working \
  flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --validate
```

### Demo dry-run (20 / 100 / 300)

```bash
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --dry-run
```

Output: `tools/catalog_import/out/dry_run/summary.json`

### Full dry-run (entire dataset, no Firestore)

```bash
CATALOG_DATA_ROOT=/Users/itayamar/catalog-working \
  flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --full-dry-run
```

Output: `tools/catalog_import/out/full_dry_run/summary.json`

Includes: planned counts, images mapped, missing images, estimated writes/batches, warnings, `generatedAt`.

Or via tests:

```bash
flutter test test/catalog_full_dry_run_test.dart
```

### Demo emulator import

```bash
firebase emulators:start --only firestore
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-demo --write --emulator
```

### Full emulator import (Phase 3)

**Requires** `--emulator` and `FIRESTORE_EMULATOR_HOST`. Refuses production.

```bash
firebase emulators:start --only firestore
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-full --write --emulator
```

- Batched writes (default 450 ops/batch)
- Progress logged every 1000 records
- `catalogMeta/current` written only after categories, products, and variants succeed
- Deterministic document IDs (safe overwrite / resume)

### Resume interrupted full import

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- \
  --import-full --write --emulator --resume
```

Checkpoint: `tools/catalog_import/out/import_checkpoint.json` (same `importVersion` required).

### Rollback catalog (emulator only)

Deletes **only** catalog collections — not `products`, `users`, `quoteRequests`, `supplierQuotes`.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --rollback-catalog --emulator
```

### Post-import verification (emulator)

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --verify-emulator --emulator
```

Output: `tools/catalog_import/out/emulator_verification/summary.json`

Checks:

- `catalogCategories` count = 418
- `catalogProducts` count = 11,149
- `catalogVariants` count = 31,551
- No orphan `variant.productId`
- `catalogMeta/current` matches live counts

Integration test (emulator must be running):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  flutter test test/catalog_emulator_integration_test.dart
```

## Known dataset warnings

Full validation may **PASS** with warnings:

1. **1313 products without `categoryIds`** — still imported; verification lists them separately.
2. **9 products reference images not on disk** — image map may still cover most assets.

These do not block emulator import.

## Production import safety

- Never run `--import-full --write` without `--emulator` and `FIRESTORE_EMULATOR_HOST`.
- Production Firestore rules block client catalog writes.
- Legacy RFQ data and `products` seed collection are never deleted by rollback.
- Use Admin SDK / Cloud Functions for a future controlled production cutover (not in this phase).

## Rollback (legacy note)

Demo/full catalog rollback on emulator uses `--rollback-catalog --emulator`. Legacy `products` and RFQ flows are unaffected.

## Architecture

See [CATALOG_ARCHITECTURE.md](CATALOG_ARCHITECTURE.md).
