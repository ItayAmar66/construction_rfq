# Deployment

## Firestore rules

```bash
firebase deploy --only firestore:rules --project construction-rfq-itay-20-2eee0
```

Deploy after any rules change. Verify with:

```bash
flutter test test/firestore_rules_security_test.dart
```

## Firestore indexes

If queries fail with index links in console, create composite indexes for:

- `memberships` collection group: `uid` ASC
- `auditEvents`: `orgId` + `createdAt` DESC; `projectId` + `createdAt` DESC
- `invitations`: `createdAt` DESC (admin panel)

## Storage CORS (catalog images)

```bash
gsutil cors set storage-cors.json gs://construction-rfq-itay-20-2eee0.appspot.com
```

Use the project's `storage-cors.json` if present in repo.

## Web hosting

```bash
flutter build web --release
firebase deploy --only hosting --project construction-rfq-itay-20-2eee0
```

Do not deploy automatically from CI without review.

## Cloud Functions (optional)

Email invite function scaffold: `tools/functions/README.md`

```bash
# When implemented:
firebase deploy --only functions:sendInvitationEmail --project construction-rfq-itay-20-2eee0
```

Required env (not in repo): `EMAIL_PROVIDER_API_KEY`, `EMAIL_FROM_ADDRESS`, `APP_BASE_URL`

## Admin bootstrap

See `docs/ADMIN_BOOTSTRAP.md` for `platformAdmin` custom claim setup.

## Catalog import

Production import is a separate operational step — **not** part of app deploy.

```bash
# Staging only, when explicitly requested:
# see tools/catalog_import/README.md
```

## Rollback

1. Hosting: Firebase Console → Hosting → release history → rollback
2. Rules: redeploy from previous git tag
3. Functions: redeploy previous version or disable trigger
