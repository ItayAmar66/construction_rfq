# Launch Checklist — Construction RFQ

## Pre-launch (required)

- [ ] `flutter analyze` — no errors
- [ ] `flutter test` — green
- [ ] Firestore rules deployed: `firebase deploy --only firestore:rules --project construction-rfq-itay-20-2eee0`
- [ ] Storage CORS configured (see `docs/DEPLOYMENT.md`)
- [ ] Platform admin custom claim set for Itay (see `docs/ADMIN_BOOTSTRAP.md`)
- [ ] Real catalog imported to staging/production (do **not** run full import during QA sprint)
- [ ] Composite indexes deployed if prompted by Firestore console
- [ ] Hosting build: `flutter build web --release`

## Accounts to verify

| Role | How |
|------|-----|
| Legacy contractor | Register or demo customer |
| Legacy supplier | Register or demo supplier |
| Platform admin | Custom claim `platformAdmin: true` |
| Org member | Accept invitation flow |

## Feature smoke

- [ ] Login / register / logout
- [ ] Create project → catalog → RFQ draft → send
- [ ] Supplier incoming → quote → customer approve → order shipped
- [ ] Invitation copy link → accept → membership visible
- [ ] Company permissions + project team
- [ ] Admin console read-only overview
- [ ] Audit history visible (org + admin)

## Known limitations (see `docs/KNOWN_LIMITATIONS.md`)

- Email invites: copy-link only until Cloud Function + provider
- Audit: client-written (not tamper-proof)
- Last-owner: client guard only (not atomic)
- Membership `uid` field: new accepts write uid; legacy docs may need backfill

## Rollback

1. Revert hosting: deploy previous Firebase Hosting release
2. Revert rules: `git checkout <tag> firestore.rules && firebase deploy --only firestore:rules`
3. App rollback: redeploy prior web build artifact
