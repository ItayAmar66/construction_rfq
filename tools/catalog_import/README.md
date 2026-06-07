# Catalog import tools

## Native CLI (required)

Do **not** use `flutter run -d chrome` — web builds cannot read `Platform.environment`.

### macOS file access

`flutter run -d macos` builds a **sandboxed macOS app**. Paths outside the project (e.g. `/Users/itayamar/catalog-working`) fail with `PathAccessException: Operation not permitted` unless Debug entitlements allow it.

**Recommended (no macOS sandbox):** use the VM runner script — same CLI, runs via `flutter test` on the host:

```bash
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

bash tools/catalog_import/run_import_cli.sh \
  --import-full --full-dry-run --production \
  --project=construction-rfq-itay-20-2eee0
```

**Alternative:** `flutter run -d macos -t tool/catalog_import_main.dart` after a **Debug** rebuild. `macos/Runner/DebugProfile.entitlements` disables the app sandbox for debug/profile only; **Release** stays sandboxed.

Terminal Full Disk Access does **not** apply to sandboxed macOS apps launched via `flutter run`.

### Emulator import (local gate)

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

bash tools/catalog_import/run_import_cli.sh --import-full --write --emulator
```

Or (after debug rebuild): `flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator`

### Production import (requires explicit flags + ADC)

**A. ADC login / setup**

```bash
# Option 1: user credentials
gcloud auth application-default login

# Option 2: service account (do not commit JSON)
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
export GCLOUD_PROJECT=construction-rfq-itay-20-2eee0
```

**B. Production dry-run / validate (local payload only — no Firestore writes)**

```bash
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

bash tools/catalog_import/run_import_cli.sh \
  --import-full --full-dry-run --production \
  --project=construction-rfq-itay-20-2eee0
```

Validate only:

```bash
bash tools/catalog_import/run_import_cli.sh \
  --validate --import-full --production \
  --project=construction-rfq-itay-20-2eee0
```

**C. Deploy rules & indexes (PRODUCTION — separate from import)**

```bash
firebase deploy --only firestore:indexes --project construction-rfq-itay-20-2eee0
# Wait for indexes READY in Firebase console
firebase deploy --only firestore:rules --project construction-rfq-itay-20-2eee0
```

Never deploy `firestore.import_emulator.rules` to production.

**D. Production import (PRODUCTION — requires all safety flags)**

Uses throttled batches (`batchSize=150`, `batchDelayMs=500`), retry on 429, and checkpoint resume.

```bash
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

bash tools/catalog_import/run_import_cli.sh \
  --import-full --write --production \
  --project=construction-rfq-itay-20-2eee0 \
  --confirm-production-import=construction-rfq-itay-20-2eee0 \
  --config=tools/catalog_import/config.full_import.production.json
```

Add `--resume` (or set `"resume": true` in config) to continue after a 429 or crash. Writes are **upserts** (idempotent). Checkpoint: `tools/catalog_import/out/import_checkpoint.json`.

**Recovery after partial import (429 quota exceeded)**

1. Verify current state:

```bash
bash tools/catalog_import/run_import_cli.sh \
  --verify-production --production \
  --project=construction-rfq-itay-20-2eee0
```

2. Resume throttled import (same config + `--resume`):

```bash
bash tools/catalog_import/run_import_cli.sh \
  --import-full --write --production --resume \
  --project=construction-rfq-itay-20-2eee0 \
  --confirm-production-import=construction-rfq-itay-20-2eee0 \
  --config=tools/catalog_import/config.full_import.production.json
```

3. Verify again:

```bash
bash tools/catalog_import/run_import_cli.sh \
  --verify-production --production \
  --project=construction-rfq-itay-20-2eee0
```

If checkpoint is missing but categories/products are complete, re-run with `--resume` after manually setting checkpoint phase to `variants` in `import_checkpoint.json`, or re-run full import (upserts all docs — slower but safe).

**E. Production verify-only (read-only, ADC required)**

```bash
bash tools/catalog_import/run_import_cli.sh \
  --verify-production --production \
  --project=construction-rfq-itay-20-2eee0
```

Output: `tools/catalog_import/out/production_verification/summary.json`

**F. Cleanup generated artifacts**

```bash
git restore tools/catalog_import/out/* 2>/dev/null || rm -rf tools/catalog_import/out/*
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

**403 batchWrite “require admin authentication”?** Emulator REST batch writes need `Authorization: Bearer owner` on every request from `EmulatorRestFirestoreBackend` (Fix 5). Safe for production: only the local Firestore emulator accepts this token. Production uses `googleapis_auth` ADC — never `Bearer owner`.

## Config files

- [config.full_import.emulator.json](config.full_import.emulator.json)
- [config.full_import.production.json](config.full_import.production.json)

## Tests

```bash
flutter test test/catalog_import_test.dart
flutter test test/catalog_full_dry_run_test.dart
flutter test test/catalog_import_safety_test.dart
flutter test test/catalog_production_import_safety_test.dart
flutter test test/catalog_production_import_retry_test.dart
flutter test test/catalog_import_macos_access_test.dart
```

See [CATALOG_IMPORT_GUIDE.md](../../CATALOG_IMPORT_GUIDE.md).
