# Catalog production deployment checklist

**Do not run production import or deploy from this doc without explicit approval.**  
Commands marked **SAFE (local)** run against emulator or dry-run only. Commands marked **PRODUCTION** modify live Firebase.

## Pre-flight

- [ ] Confirm `main` is green: `flutter analyze` + `flutter test`
- [ ] Review `firestore.rules` — catalog collections **read-only** for clients
- [ ] Review `firestore.indexes.json` — catalog variant browse/search indexes present
- [ ] **SAFE (local):** `./tools/catalog_import/run_emulator_gate.sh` — PASS
- [ ] **SAFE (local):** `flutter test test/catalog_full_dry_run_test.dart`

## Backup (before any PRODUCTION change)

- [ ] Export current Firestore catalog collections (Admin SDK or `gcloud firestore export`)
- [ ] Note current `firestore.rules` + `firestore.indexes.json` git SHA
- [ ] Tag release: `git tag catalog-pre-deploy-YYYYMMDD`

## Deploy indexes & rules (PRODUCTION — requires Firebase project access)

```bash
# PRODUCTION — deploy indexes first (non-destructive, may take minutes)
firebase deploy --only firestore:indexes --project <PROJECT_ID>

# PRODUCTION — deploy rules after review (does NOT import catalog data)
firebase deploy --only firestore:rules --project <PROJECT_ID>
```

**Never** deploy `firestore.import_emulator.rules` to production.

## Staging / prod import guard

- [ ] Import scripts must target emulator or explicit `--project` flag
- [ ] **BLOCKED by default:** batch writes to `catalogVariants` in production from client app
- [ ] Catalog import runs via Admin SDK / emulator gate CLI only (`tools/catalog_import/`)
- [ ] Verify `firebase.json` points to `firestore.rules`, not import rules

## Emulator gate (SAFE — repeat before prod import decision)

```bash
export CATALOG_DATA_ROOT=/path/to/catalog-working   # local dataset
./tools/catalog_import/run_emulator_gate.sh
```

Expected: `emulator_verification/summary.json` with matching counts + `searchFields.passed: true`.

## Post-deploy verification (PRODUCTION — read-only checks)

- [ ] Signed-in app: catalog selector loads categories/variants
- [ ] RFQ submit persists `variantId`, `isCatalogMatched` on request items
- [ ] Supplier quote preserves `isExactMatch` / `isAlternative`
- [ ] Customer compare shows match badges; approval warns on alternatives
- [ ] No client write errors on catalog collections

## Rollback

| Layer | Action |
|-------|--------|
| Rules | `git checkout <previous-sha> -- firestore.rules` then **PRODUCTION** `firebase deploy --only firestore:rules` |
| Indexes | Old indexes remain; remove unused via Firebase console if needed (non-urgent) |
| Catalog data | Restore from pre-deploy export; do not partial-delete without backup |
| App | Roll back mobile release / hotfix to previous build |

## What this checklist does NOT cover

- Production catalog **import** execution (separate ops runbook)
- App Store / Play release
- Firebase Auth or billing changes

## Related docs

- `CATALOG_SEARCH_FOUNDATION.md` — indexes + security
- `CATALOG_SUPPLIER_MATCHING.md` — RFQ match fields
- `tools/catalog_import/run_emulator_gate.sh` — emulator gate script
