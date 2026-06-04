# Catalog import guide

Structured material catalog import for Construction RFQ (not e-commerce). The legacy `products` collection, `ProductService`, seed products, and RFQ screens remain unchanged until a future cutover.

## Native CLI required (do not use Chrome)

**Why Chrome fails:** `flutter run -d chrome` compiles for Flutter Web. The import tooling uses `dart:io` `Platform.environment`, which throws on web:

`DartError: Unsupported operation: Platform._environment`

**Use the native CLI** (`tool/catalog_import_main.dart`) on **macOS** (or the gate test on VM):

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

# Single command (macOS desktop VM — no browser)
flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator

# Rollback / verify
flutter run -d macos -t tool/catalog_import_main.dart -- --rollback-catalog --emulator
flutter run -d macos -t tool/catalog_import_main.dart -- --verify-emulator --emulator

# Full gate (emulator + rollback + import + verify)
./tools/catalog_import/run_emulator_gate.sh
```

Plain `dart run tool/catalog_import_main.dart` is **not supported** on this Flutter app package (VM FFI). Use `flutter run -d macos` or `flutter test test/catalog_emulator_gate_cli_test.dart` inside `firebase emulators:exec`.

The CLI talks to the Firestore emulator over **HTTP REST** only (`FIRESTORE_EMULATOR_HOST`). It cannot reach production Firestore.

## Prerequisites

- Normalized dataset at `CATALOG_DATA_ROOT` (default `/Users/itayamar/catalog-working`)
- Flutter SDK + Java 21 (for Firebase emulator)
- `FIRESTORE_EMULATOR_HOST` for any write / rollback / verify

| Variable | Purpose |
|----------|---------|
| `CATALOG_DATA_ROOT` | Working catalog path |
| `CATALOG_IMPORT_OUTPUT` | Output dir (default `tools/catalog_import/out`) |
| `FIRESTORE_EMULATOR_HOST` | e.g. `127.0.0.1:8080` |

## CLI flags

`--validate`, `--dry-run`, `--full-dry-run`, `--import-demo`, `--import-full`, `--write`, `--emulator`, `--resume`, `--rollback-catalog`, `--verify-emulator`

Full write requires **`--emulator`**, **`--write`**, and **`FIRESTORE_EMULATOR_HOST`**.

## Collections

| Collection | Doc ID |
|------------|--------|
| `catalogCategories` | category id |
| `catalogProducts` | product id |
| `catalogVariants` | variant id |
| `catalogMeta` | `current` (written last) |

## Commands (native macOS)

### Validate (no Firestore)

```bash
flutter run -d macos -t tool/catalog_import_main.dart -- --validate
```

### Full dry-run (no Firestore)

```bash
flutter run -d macos -t tool/catalog_import_main.dart -- --full-dry-run
```

Or: `flutter test test/catalog_full_dry_run_test.dart`

Output: `tools/catalog_import/out/full_dry_run/summary.json`

### Full emulator import

```bash
firebase emulators:start --only firestore   # Terminal 1
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator
```

### Resume

```bash
flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator --resume
```

Checkpoint: `tools/catalog_import/out/import_checkpoint.json`

### Rollback (catalog only)

```bash
flutter run -d macos -t tool/catalog_import_main.dart -- --rollback-catalog --emulator
```

### Verify

```bash
flutter run -d macos -t tool/catalog_import_main.dart -- --verify-emulator --emulator
```

Output: `tools/catalog_import/out/emulator_verification/summary.json`

Expected: 418 / 11,149 / 31,551 + `catalogMeta/current`.

## Known warnings (non-fatal)

- 1313 products without `categoryIds`
- 9 products reference images not on disk

## Production safety

Never run full import without emulator env. Production client rules block catalog writes. Legacy RFQ collections are never deleted by rollback.

## Config files

- [tools/catalog_import/config.example.json](tools/catalog_import/config.example.json)
- [tools/catalog_import/config.full_import.emulator.json](tools/catalog_import/config.full_import.emulator.json)

## Architecture

See [CATALOG_ARCHITECTURE.md](CATALOG_ARCHITECTURE.md).
