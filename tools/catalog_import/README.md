# Catalog import tools

## Native CLI (required)

Do **not** use `flutter run -d chrome` — web builds cannot read `Platform.environment`.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator
```

## Emulator gate

```bash
./tools/catalog_import/run_emulator_gate.sh
```

Runs `firebase emulators:exec` + gate tests **sequentially** (import gate → search smoke) in one session.

1. `catalog_emulator_gate_cli_test.dart` — rollback, import, verify  
2. `catalog_search_emulator_smoke_test.dart` — live REST search smoke (after data is loaded)

Do not pass both test files to a single `flutter test` command — Flutter runs files concurrently and smoke would see an empty emulator.

Rollback is **idempotent**: 404 on missing root collections is treated as empty (clean emulator OK).

REST list path: `GET .../documents/{collectionId}?pageSize=N` (not `?collectionId=` on `/documents`).

**403 on rollback?** Gate must use `firestore.import_emulator.rules` (see `run_emulator_gate.sh`). Production `firestore.rules` stays locked down.

**400 batchWrite “lacks projects at index 0”?** batchWrite bodies must use canonical document names (`projects/.../documents/...`), not `http://127.0.0.1:8080/v1/...`. Fixed in `EmulatorRestFirestoreBackend` (Fix 4).

**403 batchWrite “require admin authentication”?** Emulator REST batch writes need `Authorization: Bearer owner` on every request from `EmulatorRestFirestoreBackend` (Fix 5). Safe for production: only the local Firestore emulator accepts this token.

## Tests

```bash
flutter test test/catalog_import_test.dart
flutter test test/catalog_full_dry_run_test.dart
```

See [CATALOG_IMPORT_GUIDE.md](../../CATALOG_IMPORT_GUIDE.md).
