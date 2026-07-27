# Release Operations Report — Pre-Closed-Beta

**Project:** construction_rfq
**Branch:** feature/full-project-centric-redesign
**Firebase project:** `construction-rfq-itay-20-2eee0` (single project, no dev/staging/prod tiering)
**Date:** 2026-07-27
**Method:** Static repo audit (config files, code, docs, git history). No Firebase Console or `gcloud`/`firebase` CLI access was available in this session, so anything that lives only in the live console/project is marked accordingly — it is **not** claimed as verified just because the code intends it.

Legend: ✅ Verified from repo evidence · ⚠ Needs owner action (console/CLI access required, or a real gap) · ❌ Broken / missing required artifact

---

## 1. Firebase project configuration — ✅ Verified
`.firebaserc` defines one alias, `default → construction-rfq-itay-20-2eee0`. `firebase.json` has consistent hosting/firestore/storage/emulator blocks and a `flutter.platforms` section with matching app IDs for Android, iOS, macOS, web, and Windows, all under the same project. Internally consistent; no dev/staging project exists (see §20).

## 2. Crashlytics setup — ⚠ Needs owner action
Code wiring is real: `lib/services/crashlytics_crash_reporter.dart` calls `FirebaseCrashlytics.instance`, gated by `FEATURE_CRASH_REPORTING` + non-demo + non-web. `pubspec.yaml` has `firebase_crashlytics: ^4.3.10`. However there is no native `google-services.json`/`GoogleService-Info.plist` in the repo (§4, §5), so Crashlytics cannot actually initialize on a native build today, and `docs/CRASH_REPORTING_SETUP.md` states console enablement has not been verified this session. **Owner must:** install real native config files, do a physical-device test crash, and confirm Crashlytics is enabled in the Firebase Console.

## 3. Analytics setup — ⚠ Needs owner action
`firebase_analytics: ^11.6.0` wired via `lib/analytics/app_analytics.dart`, gated by `FEATURE_ANALYTICS`. A 16-event closed-beta funnel is documented (`docs/ANALYTICS_SETUP.md`, `docs/ANALYTICS_RELEASE.md`). Same blocker as Crashlytics: no native config files present, and DebugView verification has not been done this session. **Owner must:** confirm events land in DebugView/console after native config is in place.

## 4. google-services.json — ❌ Broken
Not present. Only `android/app/google-services.json.example` is tracked, with placeholder values (`REPLACE_ME`, `YOUR_PROJECT_ID`, `YOUR_ANDROID_API_KEY`). The real file is correctly gitignored but has never existed in this checkout. The Android `google-services` Gradle plugin is applied (`android/app/build.gradle:5`) with no file to consume — a release/debug Android build will fail or silently no-op the native Firebase init at build time. **Owner must:** download the real file from the Firebase Console and place it at `android/app/google-services.json`.

## 5. GoogleService-Info.plist — ❌ Broken
Not present anywhere, and unlike Android there isn't even an `.example` template. `.gitignore` excludes both the iOS and macOS paths. **Owner must:** download from Firebase Console and place at `ios/Runner/GoogleService-Info.plist` (and macOS equivalent if that target ships).

## 6. Firebase Hosting config — ✅ Verified
`firebase.json` hosting block is valid: `public: "build/web"`, sensible ignore list, SPA rewrite (`** → /index.html`). `web/` source exists and a prior `build/web/` output is present, confirming the pipeline has been exercised at least once locally. No custom headers configured, but none are required for a baseline SPA deploy.

## 7. platformAdmin bootstrap — ⚠ Needs owner action
The security model is sound: real authorization is a Firebase Auth custom claim (`platformAdmin: true`), checked in Firestore rules and `EffectivePermissions` — not the client-side `bootstrapEmails` list in `lib/services/platform_admin.dart`, which is UI-visibility-only. The actual grant mechanism is `tools/admin/set_platform_admin.js`, a manual Node script an operator must run against the live project. Per `docs/PRE_BETA_OPERATIONS.md`, this has not been run for the production project. **Owner must:** run the bootstrap script against the live Firebase project for the intended admin account(s) before beta, and confirm via a sign-out/sign-in that the claim takes effect.

## 8. Custom claims — ⚠ Needs owner action
`tools/admin/set_platform_admin.js` uses `admin.auth().setCustomUserClaims(uid, {...existing, platformAdmin: true})` correctly (merges rather than clobbers existing claims). This is a one-off manual script, not a Cloud Function trigger — there is no automatic claim assignment on user creation. Functionally correct, but entirely dependent on a human running it per-environment/per-user. No evidence it has been executed against the live project.

## 9. Firestore indexes — ⚠ Needs owner action
`firestore.indexes.json` defines 22 composite indexes covering `quoteRequests`, `supplierQuotes`, `catalogProducts`, `catalogVariants`, `catalogCategories`, `organizations`, `accessRequests`, and they look consistent with the filter/sort patterns used in `lib/services`. This audit did not exhaustively cross-check every `.where().orderBy()` call site against the index list, and — more importantly — **this could not confirm the indexes are actually deployed and built on the live project** (index build status is console/CLI-only). **Owner must:** run `firebase deploy --only firestore:indexes` and confirm "Enabled" status for all indexes in the console before beta traffic hits any query that needs them (missing indexes fail hard at runtime).

## 10. Firestore PITR — ⚠ Needs owner action
No repo artifact would show this either way (PITR is a `gcloud`/console-only setting). `RELEASE_CHECKLIST.md` and `docs/PRE_BETA_OPERATIONS.md` both explicitly record that PITR is **not** enabled and that this was a known open item from a prior review. **Owner must:** enable PITR via `gcloud firestore databases update --database='(default)' --enable-pitr` or the console, given RFQ-delete currently has no backup safety net.

## 11. Scheduled Export — ⚠ Needs owner action
No Cloud Scheduler job, Cloud Function, or Terraform/IaC for scheduled Firestore export exists in the repo. `tools/functions/` is a scaffold/plan only, not deployed code. Docs describe only a manual, one-off `gcloud firestore export` as an option, never actually run on a schedule. **Owner must:** set up a scheduled export (Cloud Scheduler → Cloud Function or `gcloud firestore export` cron) to a GCS bucket, since this is currently the only backup mechanism absent PITR too.

## 12. Firestore TTL configuration — ⚠ Needs owner action
No TTL field policy configured anywhere (no `gcloud firestore fields ttl-config` script, nothing in rules/docs). Collections with expiry-like semantics (`invitations`, `accessRequests`) have no TTL, meaning they will accumulate indefinitely. **Owner must:** decide whether TTL is needed for these collections before beta data volume makes manual cleanup painful; this is a judgment call, not necessarily a launch blocker.

## 13. Storage rules — ✅ Verified
`storage.rules` (12 lines) is deny-by-default: only `catalog/images/{allPaths=**}` allows public read (`allow write: if false` — writes still fully locked, presumably populated via admin tooling), everything else denies both read and write unconditionally. No authenticated per-user upload path exists at all. This is intentionally conservative and matches the documented posture in `RELEASE_CHECKLIST.md`.

## 14. Authentication providers — ⚠ Needs owner action
Only email/password is implemented in code (`lib/services/auth_service.dart`, `firebase_auth: ^5.3.4`, no `google_sign_in`/`sign_in_with_apple` packages, no OAuth client IDs in native project files). This appears to be an intentional MVP scope, not a bug. What cannot be verified from the repo is whether the **Email/Password provider is actually toggled on** in the Firebase Console Authentication settings for the live project. **Owner must:** confirm in console that Email/Password sign-in is enabled (and that no unused providers like anonymous auth are accidentally left on).

## 15. Email templates — ⚠ Needs owner action
Two distinct things here:
- **Firebase Auth built-in templates** (password reset, email verification, etc.) — configured only in the console; not represented in this repo at all, so cannot be verified. **Owner must:** confirm sender name/from-address/branding are set in Authentication → Templates before beta so reset/verification emails don't show a generic Firebase default.
- **Application invitation emails** — not implemented. `tools/functions/README.md` documents a planned `sendInvitationEmail` Cloud Function (with placeholder env vars like `noreply@example.com`) that was never built. The app currently uses `DevInviteDeliveryService`, which only copies an invite link for the user to paste manually — this is a real functional gap for beta, not just a console setting, and should be flagged to the team as a product decision (ship with copy-link, or block on building the function) rather than something this report can resolve as ops-only.

## 16. Domain configuration — ✅ Verified (as-is)
No custom domain is configured in `firebase.json` or docs; hosting will serve on the default `*.web.app`/`*.firebaseapp.com` domain for `construction-rfq-itay-20-2eee0`. This is a reasonable default for a closed beta. If a custom domain is desired for beta, that's a net-new owner task (DNS + Firebase Console domain verification), not a fix to something broken.

## 17. Support email — ⚠ Needs owner action
`lib/config/app_config.dart` deliberately defaults `supportEmail` to empty (via `SUPPORT_EMAIL` dart-define) rather than fabricating one — `lib/utils/support_contact.dart` falls back to a "copy diagnostics" flow when unset, which is a safe/honest default but not what you want live in beta. Separately, the legal docs (`docs/legal/TERMS_OF_SERVICE.md`, `docs/legal/PRIVACY_POLICY.md`) still contain the literal placeholder `[support@example.com]` in 5 places — these are markdown source files that were apparently not updated when the app-side config was fixed. **Owner must:** (a) decide the real support address and pass it via `--dart-define=SUPPORT_EMAIL=...` in the beta build, and (b) fix the placeholder text in the two legal docs.

## 18. Company name — ⚠ Needs owner action
`companyLegalName` defaults to the Hebrew placeholder "צוות בקשות הצעת מחיר (גרסת בטא)" ("RFQ team (beta version)") — an intentionally honest placeholder per the code comment, not a fabricated legal name. Separately, the repo's `LICENSE` file still has an unreplaced `[COPYRIGHT HOLDER]` placeholder. **Owner must:** decide whether a real registered company/legal entity name should be passed via `--dart-define=COMPANY_LEGAL_NAME=...` for the beta build (legal docs and in-app "about" surfaces will show whatever ships), and fix the `LICENSE` placeholder if the repo will be shared externally.

## 19. AppConfig production values — ⚠ Needs owner action
`lib/config/app_config.dart` reads `APP_VERSION`, `APP_ENV`, `COMPANY_LEGAL_NAME`, `SUPPORT_EMAIL` all via `--dart-define`, defaulting to dev-safe values (`environment=dev`, `verboseDiagnostics=true` when not prod, empty support email) if none are passed. There is currently **no build pipeline or flavor that enforces passing the production dart-defines** — a build run without them would silently ship as `dev` with verbose diagnostics on. `pubspec.yaml` version is also still the untouched template `1.0.0+1`. **Owner must:** define and use an actual beta-release build command (or CI job) that passes the full set of production dart-defines, and bump `pubspec.yaml` version.

## 20. Environment separation — ⚠ Needs owner action
No Android product flavors, no iOS/macOS build schemes beyond the single default `Runner.xcscheme`, and only one `.firebaserc` alias — meaning dev and prod share one Firebase project with no infrastructure-level isolation. Separation exists only at the Dart level (`--dart-define` + `FeatureFlags.fromEnvironment()`), which is fragile against the "forgot to pass a flag" failure mode in §19. This is called out as a known gap in `RELEASE_CHECKLIST.md §7`. **Owner must:** decide if a second Firebase project for dev/QA is warranted before beta, or explicitly accept the single-project risk for this beta cycle.

## 21. Secrets not committed — ✅ Verified
`.gitignore` correctly excludes `android/app/google-services.json`, both `GoogleService-Info.plist` locations, `android/key.properties`, `*.jks`, `.env*`, and `tools/admin/node_modules`/`backups`. `git log --all` for secret-shaped filenames turned up no real matches (one false-positive commit message hit). `git grep` for `BEGIN PRIVATE KEY` / `"type": "service_account"` only matches vendored `node_modules` documentation, not real credentials. `git ls-files` confirms only the placeholder `google-services.json.example` is tracked. The one real weakness — hardcoded QA/admin test passwords (`Qa123456!`, `123123`) in `tools/qa/*.py` and `tools/admin/*.js` — is a known, separately-tracked issue (not an API key/service-account leak) and doesn't change this verdict, but should still be rotated/removed before any public beta given `lib/screens/admin/admin_management_panel.dart` also references one.

---

## Summary

| # | Item | Status |
|---|---|---|
| 1 | Firebase project configuration | ✅ |
| 2 | Crashlytics setup | ⚠ |
| 3 | Analytics setup | ⚠ |
| 4 | google-services.json | ❌ |
| 5 | GoogleService-Info.plist | ❌ |
| 6 | Firebase Hosting config | ✅ |
| 7 | platformAdmin bootstrap | ⚠ |
| 8 | Custom claims | ⚠ |
| 9 | Firestore indexes | ⚠ |
| 10 | Firestore PITR | ⚠ |
| 11 | Scheduled Export | ⚠ |
| 12 | Firestore TTL configuration | ⚠ |
| 13 | Storage rules | ✅ |
| 14 | Authentication providers | ⚠ |
| 15 | Email templates | ⚠ |
| 16 | Domain configuration | ✅ |
| 17 | Support email | ⚠ |
| 18 | Company name | ⚠ |
| 19 | AppConfig production values | ⚠ |
| 20 | Environment separation | ⚠ |
| 21 | Secrets not committed | ✅ |

**Two hard blockers (❌):** missing `google-services.json` and `GoogleService-Info.plist` — without these, native Firebase features (Crashlytics, Analytics, and potentially push/native Auth flows) cannot function on mobile builds regardless of app-side code correctness.

**Everything else marked ⚠ requires a human with Firebase Console / `gcloud` / hosting-account access** — none of it can be completed by an agent working only in this repo. No external console actions were attempted or claimed as completed in this report.
