# Catalog import guide

This document describes how to validate, dry-run, and import the **demo slice** of the external catalog into Firestore collections `catalogCategories`, `catalogProducts`, `catalogVariants`, and `catalogMeta`.

The legacy `products` collection, `ProductService`, seed products, and RFQ screens are **not** modified by this pipeline.

## Prerequisites

- Normalized dataset (JSONL + category forest), default path:
  `/Users/itayamar/catalog-working`
- Flutter SDK and project dependencies (`flutter pub get`)
- For **writes**: Firestore emulator (recommended) or Admin SDK (not included in this phase)

Environment variables:

| Variable | Purpose |
|----------|---------|
| `CATALOG_DATA_ROOT` | Root of catalog-working (contains `normalized/`) |
| `CATALOG_IMPORT_OUTPUT` | Dry-run JSON output directory |
| `FIRESTORE_EMULATOR_HOST` | e.g. `127.0.0.1:8080` when using `--write` |

## Collections

| Collection | Document ID | Content |
|------------|-------------|---------|
| `catalogCategories` | category id (string) | `CatalogCategory` |
| `catalogProducts` | product id (string) | `CatalogProduct` |
| `catalogVariants` | variant id (string) | `CatalogVariant` |
| `catalogMeta` | `current` | counts, version, import timestamp |

Rules: client reads allowed; writes blocked in production rules — use emulator for demo import.

## Import process

### 1. Validate full source dataset (no writes)

Checks products, variants, categories, image references, and parent relationships on the **full** normalized files.

```bash
cd construction_rfq
CATALOG_DATA_ROOT=/Users/itayamar/catalog-working \
  flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --validate
```

### 2. Dry-run demo slice (20 / 100 / 300)

Builds ETL output and writes JSON under `tools/catalog_import/out/` (no Firestore).

```bash
flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --dry-run
```

Or with explicit root:

```bash
CATALOG_DATA_ROOT=/Users/itayamar/catalog-working \
  CATALOG_IMPORT_OUTPUT=tools/catalog_import/out \
  flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --dry-run
```

### 3. Import demo slice to Firestore (emulator)

Start emulator, point client at it, then:

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
CATALOG_DATA_ROOT=/Users/itayamar/catalog-working \
  flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --import-demo --write
```

**Do not** run full-dataset import until a later phase approves it.

### 4. Unit tests (mini fixture + optional full dataset)

```bash
flutter test test/catalog_import_test.dart test/catalog_repository_test.dart
```

The full-dataset test runs only when `/Users/itayamar/catalog-working/normalized/products.jsonl` exists.

## Validation process

The validator (`CatalogValidator`) reports:

- Every product has resolvable categories
- Every variant references an existing product
- Category parent chains are acyclic and valid
- Image map entries resolve when `imageMap.json` is present
- Demo slice limits: ≤20 categories, ≤100 products, ≤300 variants

Validation runs automatically before import in `CatalogImportPipeline`.

## Rollback process

This phase does **not** migrate or delete legacy `products` data.

To remove a **demo import** from catalog collections only:

1. **Emulator**: stop emulator or delete project data directory.
2. **Production** (if demo was written via Admin path later): delete documents in:
   - `catalogCategories`
   - `catalogProducts`
   - `catalogVariants`
   - `catalogMeta/current`

Legacy RFQ catalog continues to use `products` + `ProductService` until a future cutover.

## Configuration

Example: [tools/catalog_import/config.example.json](tools/catalog_import/config.example.json)

Dart config: `lib/catalog_import/import_config.dart` and CLI flags in `lib/dev/catalog_import_main.dart`.

## Architecture reference

See [CATALOG_ARCHITECTURE.md](CATALOG_ARCHITECTURE.md) for domain models, repository API, and indexing strategy.
