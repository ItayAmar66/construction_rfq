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

Runs `firebase emulators:exec` + `flutter test test/catalog_emulator_gate_cli_test.dart` (rollback → import → verify).

Rollback is **idempotent**: 404 on missing root collections is treated as empty (clean emulator OK).

REST list path: `GET .../documents/{collectionId}?pageSize=N` (not `?collectionId=` on `/documents`).

## Tests

```bash
flutter test test/catalog_import_test.dart
flutter test test/catalog_full_dry_run_test.dart
```

See [CATALOG_IMPORT_GUIDE.md](../../CATALOG_IMPORT_GUIDE.md).
