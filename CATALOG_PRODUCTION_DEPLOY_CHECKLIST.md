# Catalog production deployment checklist

**Do not run production import or deploy from this doc without explicit approval.**  
Commands marked **SAFE (local)** run against emulator or dry-run only. Commands marked **PRODUCTION** modify live Firebase.

## Pre-flight

- [ ] Confirm `main` is green: `flutter analyze` + `flutter test`
- [ ] Review `firestore.rules` — catalog collections **read-only** for clients
- [ ] Review `firestore.indexes.json` — catalog variant browse/search indexes present
- [ ] Run `test/firestore_rules_security_test.dart` — PASS
- [ ] **SAFE (local):** `./tools/catalog_import/run_emulator_gate.sh` — PASS
- [ ] **SAFE (local):** `flutter test test/catalog_full_dry_run_test.dart`
- [ ] Review `PRODUCTION_READINESS_SCORECARD.md` — no blockers for intended scope

## Backup (before any PRODUCTION change)

- [ ] Export current Firestore catalog collections (Admin SDK or `gcloud firestore export`)
- [ ] Export quoteRequests + supplierQuotes snapshot if rolling back RFQ data matters
- [ ] Note current `firestore.rules` + `firestore.indexes.json` git SHA
- [ ] Tag release: `git tag catalog-pre-deploy-YYYYMMDD`

## Deploy indexes & rules (PRODUCTION — requires Firebase project access)

```bash
# PRODUCTION — deploy indexes first (non-destructive, may take minutes)
firebase deploy --only firestore:indexes --project construction-rfq-itay-20-2eee0

# Wait until Firebase console shows indexes READY

# PRODUCTION — deploy rules after review (does NOT import catalog data)
firebase deploy --only firestore:rules --project construction-rfq-itay-20-2eee0
```

**Never** deploy `firestore.import_emulator.rules` to production.

## Production catalog import (PRODUCTION — explicit flags required)

**ADC setup (once per machine)**

```bash
gcloud auth application-default login
# OR: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
export GCLOUD_PROJECT=construction-rfq-itay-20-2eee0
```

**A. Dry-run / validate (SAFE — local payload, no Firestore writes)**

```bash
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

flutter run -d macos -t tool/catalog_import_main.dart -- \
  --import-full --full-dry-run --production \
  --project=construction-rfq-itay-20-2eee0
```

**B. Deploy rules/indexes** — see section above.

**C. Production import (PRODUCTION — throttled + resumable)**

```bash
export CATALOG_DATA_ROOT=/Users/itayamar/catalog-working

bash tools/catalog_import/run_import_cli.sh \
  --import-full --write --production --resume \
  --project=construction-rfq-itay-20-2eee0 \
  --confirm-production-import=construction-rfq-itay-20-2eee0 \
  --config=tools/catalog_import/config.full_import.production.json
```

**429 recovery:** wait 2–5 min → throttled verify (D) → resume import (C) → verify again (D). See `tools/catalog_import/README.md`.

**D. Production verify-only (PRODUCTION — read-only, ADC, throttled reads)**

```bash
bash tools/catalog_import/run_import_cli.sh \
  --verify-production --production \
  --project=construction-rfq-itay-20-2eee0 \
  --config=tools/catalog_import/config.full_import.production.json
```

Expected: `tools/catalog_import/out/production_verification/summary.json` with 418 / 11,149 / 31,551 counts + `searchFields.passed: true` + query smoke.

**E. Cleanup artifacts**

```bash
git restore tools/catalog_import/out/* 2>/dev/null || rm -rf tools/catalog_import/out/*
```

## Staging import guard

- [ ] Import scripts must target emulator or explicit `--project` flag
- [ ] **BLOCKED by default:** batch writes to `catalogVariants` in production from client app
- [ ] Catalog import runs via ADC REST CLI (`tools/catalog_import/`) or emulator gate only
- [ ] Verify `firebase.json` points to `firestore.rules`, not import rules
- [ ] Staging import: run emulator gate on staging dataset copy before prod decision

## Emulator gate (SAFE — repeat before prod import decision)

```bash
export CATALOG_DATA_ROOT=/path/to/catalog-working   # local dataset
./tools/catalog_import/run_emulator_gate.sh
```

Expected: `emulator_verification/summary.json` with matching counts + `searchFields.passed: true`.

Gate must PASS before any staging/prod import approval.

## Post-deploy verification (PRODUCTION — read-only checks)

- [ ] `catalogMeta/current` exists with `variantCount > 0`, `categoryCount > 0`
- [ ] Signed-in app: catalog selector loads first 50 variants (paginated browse)
- [ ] Selector shows **הקטלוג האמיתי עדיין לא נטען למערכת** when meta missing (no fake items)
- [ ] RFQ submit persists `variantId`, `isCatalogMatched` on request items
- [ ] Supplier quote preserves `isExactMatch` / `isAlternative`
- [ ] Customer compare shows match badges; approval warns on alternatives
- [ ] No client write errors on catalog collections
- [ ] Run `REAL_DEVICE_QA_SCRIPT.md` on staging build

## Rollback

| Layer | Action |
|-------|--------|
| Rules | `git checkout <previous-sha> -- firestore.rules` then **PRODUCTION** `firebase deploy --only firestore:rules` |
| Indexes | Old indexes remain; remove unused via Firebase console if needed (non-urgent) |
| Catalog data | Restore from pre-deploy export; do not partial-delete without backup |
| RFQ data | Restore quoteRequests/supplierQuotes from backup if corrupted |
| App | Roll back mobile release / hotfix to previous build |

## What this checklist does NOT cover

- App Store / Play release
- Firebase Auth or billing changes

## Related docs

- `CATALOG_SEARCH_FOUNDATION.md` — indexes + security
- `CATALOG_SUPPLIER_MATCHING.md` — RFQ match fields
- `tools/catalog_import/run_emulator_gate.sh` — emulator gate script
