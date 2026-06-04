# Catalog import tools

CLI entry point: `lib/dev/catalog_import_main.dart`

See project root: [CATALOG_IMPORT_GUIDE.md](../../CATALOG_IMPORT_GUIDE.md)

Quick start:

```bash
# Unit tests + mini fixture dry-run
flutter test test/catalog_import_test.dart

# Full dataset validate (local path)
CATALOG_DATA_ROOT=/Users/itayamar/catalog-working \
  flutter run -t lib/dev/catalog_import_main.dart -d chrome -- --validate
```
