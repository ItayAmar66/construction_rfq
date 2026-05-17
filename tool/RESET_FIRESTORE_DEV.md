# Reset Firestore development data

**DEV / MVP only. Do not run against a production Firebase project.**

This deletes all documents in these Firestore collections:

- `users`
- `products`
- `quoteRequests`
- `supplierQuotes`
- `quoteRequestItems` (legacy, if present)
- `supplierQuoteItems` (legacy, if present)

It does **not**:

- Run automatically on app startup
- Delete **Firebase Authentication** users (only Firestore `users` profile documents)

After reset, sign-in may fail with “profile missing” until you register again or delete Auth users in the [Firebase Console](https://console.firebase.google.com/) → **Authentication**.

---

## Prerequisites

1. From the project root: `construction_rfq`
2. Firebase configured (`lib/firebase_options.dart` points at your dev project)
3. Firestore security rules allow your signed-in user to delete (or use **Firestore rules test mode** / temporarily relaxed rules for dev)

---

## Recommended: Flutter dev script (double confirmation)

```bash
cd /path/to/construction_rfq
flutter pub get
flutter run -t lib/dev/reset_firestore_dev_main.dart -d chrome -- --confirm
```

> Use `lib/dev/reset_firestore_dev_main.dart` as the target (not `tool/…`).
> Files under `tool/` cannot import `lib/` with relative paths when run via `flutter run -t`.

You will be prompted to:

1. Type exactly: `DELETE ALL DEV DATA`
2. Confirm with `y`

### Optional flags (after `--`)

| Flag | Meaning |
|------|---------|
| `--confirm` | **Required.** Acknowledges you read this doc |
| `--include-app-meta` | Also deletes `appMeta` (e.g. product seed flag) |
| `--yes-phrase` | Skips typing the phrase (still requires `--confirm` and `y`) |

Example with seed flag reset:

```bash
flutter run -t lib/dev/reset_firestore_dev_main.dart -d chrome -- --confirm --include-app-meta
```

---

## Alternative: Firebase CLI (entire database)

If you use the Firebase CLI and want to wipe **all** collections in the project (not just app collections):

```bash
firebase firestore:delete --all-collections --project YOUR_PROJECT_ID
```

You will be asked to confirm. **This is broader than the app script** — use only on a dedicated dev project.

---

## Alternative: Firestore Emulator

If you develop against the emulator, stop the app, clear emulator data, and restart:

```bash
firebase emulators:start --only firestore
```

Emulator data is ephemeral unless you export/import.

---

## Files

| File | Purpose |
|------|---------|
| `lib/dev/firestore_dev_reset.dart` | Batch delete logic (do not import from production UI) |
| `lib/dev/reset_firestore_dev_main.dart` | CLI entry point with confirmations |
| `tool/reset_firestore_dev_main.dart` | Re-export only (do not use as `-t` target) |
| `scripts/reset_firestore_dev.sh` | Shell wrapper (optional) |

---

## Safety checklist

- [ ] Project ID in the console output is your **dev** project, not production
- [ ] You have a backup if needed
- [ ] Teammates know the dev database was wiped
- [ ] You will re-register test users or clear Auth in the console
