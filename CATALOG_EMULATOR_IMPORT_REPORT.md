# Catalog emulator import report (Phase 3.5)

**Agent ID:** 270711ee-545c-4b45-b1ea-28597a646a7d  
**Updated:** Phase 4.5 Finalize — search import gate **PASS** (2026-06-04, Terminal.app)

## Root cause (Chrome failure)

`flutter run -d chrome -t lib/dev/catalog_import_main.dart` compiles for **Flutter Web**. Import config uses `dart:io` `Platform.environment`, which is unsupported on web:

```
DartError: Unsupported operation: Platform._environment
```

## Fix applied

- **Native CLI:** `lib/catalog_import/catalog_import_cli.dart` + `tool/catalog_import_main.dart`
- **Firestore I/O:** `EmulatorRestFirestoreBackend` — HTTP REST to `FIRESTORE_EMULATOR_HOST` only (no `cloud_firestore` / Firebase init in CLI)
- **Gate script:** `tools/catalog_import/run_emulator_gate.sh` runs import gate then search smoke **sequentially** inside one `firebase emulators:exec` (no Chrome)
- **Deprecated:** `lib/dev/catalog_import_main.dart` delegates to the same CLI (do not use with `-d chrome`)

## Exact commands that work

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working
cd construction_rfq

# One-shot gate (recommended)
./tools/catalog_import/run_emulator_gate.sh

# Or manual steps on macOS VM:
flutter run -d macos -t tool/catalog_import_main.dart -- --rollback-catalog --emulator
flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator
flutter run -d macos -t tool/catalog_import_main.dart -- --verify-emulator --emulator
```

**Note:** `dart run tool/catalog_import_main.dart` fails on this Flutter package (VM FFI). Use `flutter run -d macos` or the gate test.

## Emulator rules fix (Phase 3.5 Fix 3)

**Symptom:** `list failed (403)` — `false for 'list' @ L63` (production `firestore.rules` on emulator).

**Cause:** Import gate uses **unauthenticated** Firestore REST. Production rules allow catalog `read` only when `request.auth != null` and deny `write`.

**Fix (Option B):** `firestore.import_emulator.rules` — used **only** by `run_emulator_gate.sh` temp emulator config. Allows read/write on `catalog*` collections on localhost. **`firestore.rules` unchanged** (not deployed from import rules file).

## batchWrite document names fix (Phase 3.5 Fix 4)

**Symptom:** `batchWrite failed (400)` — document name lacks `"projects"` at index 0.

**Cause:** `batchWrite` request bodies used the full HTTP document URL (`http://127.0.0.1:8080/v1/projects/...`) in `update.name` / `delete`. Firestore REST requires canonical resource names: `projects/{projectId}/databases/(default)/documents/{collection}/{id}`.

**Fix:** `EmulatorRestFirestoreBackend` uses `_canonicalDocName()` for batchWrite bodies only. GET/DELETE/PATCH URLs still use the emulator HTTP base URL.

## batchWrite admin auth fix (Phase 3.5 Fix 5)

**Symptom:** `batchWrite failed (403)` — `Batch writes require admin authentication.`

**Cause:** Firestore emulator REST `batchWrite` requires admin credentials; unauthenticated POSTs are rejected even with import emulator rules.

**Fix:** All emulator REST requests from `EmulatorRestFirestoreBackend` send `Authorization: Bearer owner` (emulator admin token). Backend refuses construction unless `--emulator` mode, `FIRESTORE_EMULATOR_HOST` (or explicit localhost host in tests), and host is `127.0.0.1` / `localhost`. **Production `firestore.rules` unchanged** — this header is only honored by the local emulator, not production Firestore.

## Rollback idempotency fix (Phase 3.5 Fix 2)

**Symptom:** Gate failed on clean emulator with `HttpException: list failed (404)` when listing `catalogCategories` before any import.

**Cause:** Wrong REST list URL — used `GET .../documents?collectionId=catalogCategories` (404 on emulator). Correct path: `GET .../documents/catalogCategories?pageSize=N`.

**Fix:** `EmulatorRestFirestoreBackend` treats **404 as empty collection** for list/delete/count. Rollback is safe on a clean emulator.

## Gate / import / verification / search smoke (local run 2026-06-04)

**Command:** `./tools/catalog_import/run_emulator_gate.sh` (Terminal.app)

| Step | Status |
|------|--------|
| Gate | **PASS** |
| Rollback | **PASS** |
| Full import | **PASS** |
| Verification | **PASS** |
| Search smoke | **PASS** |
| Runtime | **163 seconds** |

**Counts (verified):**

| Metric | Result |
|--------|--------|
| catalogCategories | 418 |
| catalogProducts | 11,149 |
| catalogVariants | 31,551 |
| catalogMeta/current | exists (`catalog-full-v1`) |
| Orphan variants | 0 |
| searchFields.passed | **true** |
| searchFields.variantsChecked | 31,551 |
| searchFields.variantsFailed | 0 |
| Products without categories | 1,313 (known dataset warning) |
| Errors | 0 |

**Warnings:** `1313 products have empty categoryIds (known dataset issue)` — expected; not a gate failure.

**Verification artifact:** `tools/catalog_import/out/emulator_verification/summary.json`

```json
{
  "passed": true,
  "categoryCount": 418,
  "productCount": 11149,
  "variantCount": 31551,
  "orphanVariants": 0,
  "searchFields": { "passed": true, "variantsChecked": 31551, "variantsFailed": 0 },
  "errors": [],
  "generatedAt": "2026-06-04T20:53:17.331384Z"
}
```

## Java

Temurin 21 at `~/.local/jdk/jdk-21.0.6+7/Contents/Home` or `brew install openjdk@21`.

## Production writes

**None.** REST backend refuses non-local hosts.

## Phase 4.5 — Search fields on full import

After Phase 4 search field generation, **re-run the emulator gate** so all `catalogVariants` documents include `searchTokens`, `displayNameLower`, `skuLower`, `categoryIds`, and `isActive`.

**Verification added:**

- `CatalogVariantSearchFieldVerifier` — all variants in dry-run payload and emulator
- `summary.json` → `searchFields.passed` / `variantsFailed`
- Tests: `catalog_full_dry_run_test.dart`, `catalog_search_emulator_smoke_test.dart`

**Full dry-run (local):** PASS — 31,551 variants checked, `searchFields.passed: true` (see `tools/catalog_import/out/full_dry_run/summary.json`).

**Emulator gate (local):** **PASS** — rollback → import → verify → search smoke sequential in one `emulators:exec` session (**163s**). Browse category sampled from imported variants (`pickBrowseSeedFromVariants`).

**Search smoke (VM-safe):** REST `:runQuery` via `EmulatorRestCatalogSearchRepository` — no FirebaseCore.

## Final verdict

**Phase 3.5: PASS** · **Phase 4.5: PASS** (2026-06-04) — Full import with search fields on all 31,551 variants; live search smoke against emulator data. Production Firestore not written.
