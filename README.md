# Construction RFQ

Hebrew RTL app for construction material procurement: engineers and contractors build **RFQ drafts**, send them to suppliers, compare quotes, and approve orders. This is **not** an e-commerce store.

## Stack

- Flutter (Riverpod, GoRouter)
- Firebase Auth + Cloud Firestore
- Catalog import CLI (`tools/catalog_import/`)

## Setup

```bash
flutter pub get
```

Configure Firebase: `lib/firebase_options.dart` (from FlutterFire). Do not commit secrets.

Catalog data root (import): set `CATALOG_DATA_ROOT` to the prepared catalog working directory.

## Run

```bash
flutter run
```

Debug-only dev routes: `/dev/catalog-selector`, `/dev/catalog-ops`.

## Tests

```bash
flutter analyze
flutter test
```

## Catalog status

- Production catalog import is **partial** (~8k / 31k variants as of last gate).
- Production selector uses **Firestore catalog only** — no demo/fake products in production UI.
- Resume import only when ready; see `tools/catalog_import/README.md`.
- Do **not** run production import/verify from CI without explicit approval.

## QA script (smoke)

1. Login as customer → open **טיוטת בקשה** → add catalog item + manual item → **שליחה לספקים**.
2. Login as supplier → **בקשות נכנסות** → submit quote (exact + alternative).
3. Customer → **השוואת הצעות** → approve → **הזמנות פעילות**.
4. Catalog selector: category picker, text search, load-more, partial-catalog banner if meta missing.

## Current limitations

- Partial catalog coverage until full import completes.
- Category + text search may over-fetch when scoped (Firestore composite limits).
- Legacy `/cart` route kept for compatibility; UI uses RFQ draft language.
- Demo login and scenario panels appear only in **debug + demo mode**.

## Docs

- `tools/catalog_import/README.md` — import/verify commands
- `CATALOG_PRODUCTION_DEPLOY_CHECKLIST.md` — production gates
