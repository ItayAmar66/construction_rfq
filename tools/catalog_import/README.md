# Catalog import tools

CLI entry point: `lib/dev/catalog_import_main.dart`

See project root: [CATALOG_IMPORT_GUIDE.md](../../CATALOG_IMPORT_GUIDE.md)

Quick start:

```bash
# Unit tests + mini fixture dry-run
flutter test test/catalog_import_test.dart

# Full dry-run (no Firestore, no Java)
flutter test test/catalog_full_dry_run_test.dart

# Full emulator import + verify (requires Java + firebase emulator)
firebase emulators:start --only firestore
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  flutter test test/catalog_emulator_integration_test.dart
```

See [CATALOG_IMPORT_GUIDE.md](../../CATALOG_IMPORT_GUIDE.md) for all commands.
