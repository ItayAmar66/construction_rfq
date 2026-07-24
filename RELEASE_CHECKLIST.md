# Production Release Checklist — construction_rfq

Generated from a full production-readiness audit. Legend:

- ✅ **Done** — in place and production-safe.
- 🟡 **Scaffolded** — safe seam/scaffold added in this pass; still needs wiring to a real backend or brand asset.
- ⛔ **Blocker** — must be resolved before a store/production release.
- 📋 **Manual** — a human decision or external asset/credential is required.

Firebase project (single, no tiering): `construction-rfq-itay-20-2eee0`.

---

## 0. Release blockers (do these first)

| # | Blocker | Where | Action |
|---|---------|-------|--------|
| ⛔ 1 | **Android release is signed with the debug keystore** | `android/app/build.gradle:30-34` | Create an upload keystore, add `android/key.properties` (template added: `android/key.properties.example`), wire a real `signingConfigs.release`. See §7. |
| ⛔ 2 | **Duplicate, conflicting Gradle files** — Groovy (`build.gradle`, `settings.gradle`) is active; Kotlin-DSL (`.kts`) is dead but committed, with a *different* applicationId | `android/` and `android/app/` | Pick one DSL and delete the other set. Reconcile the app id (see §9). Groovy currently wins → `com.construction.rfq`. |
| ⛔ 3 | **Three different application identifiers** | Android `com.construction.rfq`; iOS `com.construction.constructionRfq`; dead `.kts` `com.construction.construction_rfq` | Decide the canonical id, confirm it matches the id registered in the Firebase console, and align all platforms. |
| ⛔ 4 | **`google-services` plugin applied but `google-services.json` is absent** | `android/app/build.gradle:5` | Either add the (git-ignored) `google-services.json`, or remove the plugin — Firebase is initialized from `lib/firebase_options.dart`, so the plugin is optional here. |
| ⛔ 5 | **No privacy policy / terms are published & linked from the store listing** | store metadata | Finalize `docs/legal/*` (drafts added), host them, and add the URLs to the App Store / Play listings. In-app links now exist (§14). |
| ⛔ 6 | **Default (unbranded) app icons & native splash** | `android/.../mipmap-*`, `ios/.../AppIcon.appiconset`, launch screens | Add brand art and generate (see §11–12). Store review rejects default Flutter icons. |

---

## 1. Logging — 🟡 Scaffolded

- **Before:** ~92 ad-hoc `debugPrint('[Tag]…')` calls, all `kDebugMode`-guarded (nothing leaks in release), but no central abstraction. `debugPrint` is **not** stripped in release, so the guards are load-bearing.
- **Added:** `lib/utils/app_logger.dart` — a single `AppLogger` facade (`debug/info/warn/error`) that prints in debug, forwards errors to the crash reporter, and can push all records to an optional `LogSink` (remote logging). `main.dart` now emits a PII-free boot log through it.
- **To do:** migrate high-value call sites (repositories/services) to `AppLogger`; add a remote `LogSink` if central log aggregation is wanted. Review debug logs that include PII (uid/email/name) in `lib/services/auth_service.dart` — release-safe today but avoid promoting them to always-on sinks.

## 2. Analytics — 🟡 Scaffolded (no-op in prod)

- **Before/now:** `lib/analytics/catalog_rfq_analytics.dart` defines the `CatalogRfqAnalytics` interface with 6 events already fired from the UI, but `catalogRfqAnalyticsProvider` resolves to a **no-op in production**. No `firebase_analytics` dependency.
- **To do:** add `firebase_analytics` (native config), implement `CatalogRfqAnalytics`, and swap the prod branch of the provider. Gate delivery behind the new `FeatureFlags.analyticsEnabled` (`--dart-define=FEATURE_ANALYTICS=true`). Confirm a privacy/consent story before enabling.

## 3. Crash reporting — 🟡 Scaffolded (seam added)

- **Before:** none. Uncaught async errors were swallowed in release (`PlatformDispatcher.onError` returned true with only a debug print).
- **Added:** `lib/services/crash_reporter.dart` — `CrashReporter` abstraction with a safe `NoOpCrashReporter` default. `BootstrapErrorHandling.install()` now forwards **both** `FlutterError.onError` and `PlatformDispatcher.onError` to `CrashReporter.instance`, in every build. Enabling reporting is now a one-line change.
- **To do:** add `firebase_crashlytics` (or Sentry), implement `CrashReporter`, and set `CrashReporter.instance = …` in `main.dart`, gated on `FeatureFlags.crashReportingEnabled`. (No custom `runZonedGuarded` is needed — `PlatformDispatcher.onError` already covers async errors and avoids the zone-mismatch pitfall.)

## 4. Feature flags — 🟡 Scaffolded

- **Before:** none (only the demo/Firebase `AppMode` toggle).
- **Added:** `lib/config/feature_flags.dart` — build-time flags via `--dart-define` (`FEATURE_ANALYTICS`, `FEATURE_CRASH_REPORTING`, `FEATURE_DEMO_LOGIN`) with prod-safe defaults, exposed through `featureFlagsProvider`. Risky flags default **off**; demo login can never be on in a prod build.
- **To do:** for runtime kill-switches / staged rollout without a new release, back `featureFlagsProvider` with Firebase Remote Config.

## 5. Environment configuration — 🟡 Scaffolded

- **Before:** none. A single Firebase project is hardcoded everywhere; no `--dart-define`/`.env`.
- **Added:** `lib/config/app_config.dart` — `AppEnvironment {dev, staging, prod}` resolved from `--dart-define=APP_ENV=…`, plus `APP_VERSION`. Defaults keep local builds flagless.
- **To do:** create separate Firebase projects (or at least separate Firestore data) for staging vs prod; select `firebase_options` per environment. Today test/QA and real data share one project (see §6).

## 6. Secrets — 🟡 Mostly OK, one item to fix

- ✅ `lib/firebase_options.dart` client keys are **expected** to ship (Firebase client keys, not server secrets). Security relies on `firestore.rules` / `storage.rules`.
- ✅ `.gitignore` correctly excludes `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `*.jks`, `.env*`, and `tools/admin/node_modules`.
- ✅ No server-side service-account JSON / private keys are committed (Admin tools use Application Default Credentials).
- 📋 **Fix:** hardcoded weak QA/admin passwords are committed and target the shared prod project — e.g. `Qa123456!`, `123123` in `tools/qa/*.py`, `tools/admin/admin_onboarding.js`, `tools/admin/manual_qa_reset.js`. **Rotate these credentials, move QA accounts to a non-prod project, and read secrets from env vars instead of literals.**

## 7. Build flavors — 📋 Manual

- **Before/now:** no Android product flavors, no iOS build configs/schemes for dev/staging/prod.
- **To do:** add `dev`/`staging`/`prod` flavors (Android `productFlavors`, iOS schemes + xcconfigs), each pointing at the right Firebase project and passing `--dart-define=APP_ENV`. Align with §5.

## 8. CI/CD — 🟡 Scaffolded

- **Before:** none.
- **Added:** `.github/workflows/ci.yml` — on push/PR: `flutter pub get` → format check → `flutter analyze` → `flutter test`, then a gated `flutter build web --release`. Pinned to Flutter 3.44.0.
- **To do:** add a signed release job for Android/iOS (needs keystore + Apple signing secrets in CI), and a **reviewed** deploy step for Firestore rules/indexes/hosting (`docs/DEPLOYMENT.md` explicitly says do not auto-deploy without review).

## 9. Versioning — ✅ Wired / 📋 bump before ship

- ✅ `versionCode`/`versionName` (Android) and `CFBundleShortVersionString`/`CFBundleVersion` (iOS) are correctly derived from pubspec `version:`.
- 📋 Current version is still the template `1.0.0+1` — bump before submission. CI can stamp `--dart-define=APP_VERSION=…` for the in-app About screen.
- 📋 No changelog — consider `CHANGELOG.md` / release notes going forward.

## 10. App icons — ⛔ Default

- Android `mipmap-*/ic_launcher.png` and iOS `AppIcon.appiconset` are stock Flutter template icons; `flutter_launcher_icons` is not configured.
- **To do:** add a 1024×1024 source icon, configure `flutter_launcher_icons`, regenerate for all platforms + `web/icons/` + `web/favicon.png`.

## 11. Splash — ⛔ Default

- Android `launch_background.xml` and iOS `LaunchScreen.storyboard`/`LaunchImage` are stock. The Hebrew `LoadingView` is a runtime widget, **not** the native splash.
- **To do:** configure `flutter_native_splash` (brand color `#0E2748`) so users don't see a blank white OS launch screen.

## 12. Privacy policy — 🟡 Draft added

- **Added:** `docs/legal/PRIVACY_POLICY.md` (draft, bilingual notes) + in-app Hebrew copy in `lib/utils/legal_content.dart`, linked from Profile → "אודות ומשפטי".
- **To do:** fill placeholders (entity, contact, jurisdiction, retention), get legal review, host publicly, and link from the store listings.

## 13. Terms — 🟡 Draft added

- **Added:** `docs/legal/TERMS_OF_SERVICE.md` (draft) + in-app Hebrew copy, linked from Profile.
- **To do:** same as §12 — finalize, legal-review, host, link.

## 14. Licenses — ✅ Done

- **Added:** in-app "רישיונות קוד פתוח" (Open-source licenses) entry via Flutter's `showLicensePage` (real third-party attributions), on the new About & Legal screen (`lib/screens/profile/about_legal_screen.dart`, route `/about`).
- **Added:** root `LICENSE` (proprietary; replace `[COPYRIGHT HOLDER]`).

## 15. Error reporting — 🟡 Scaffolded

- Covered by §3 (crash reporter seam) and the in-app fallback `ErrorWidget.builder` (Hebrew panel instead of a red screen). Data-layer streams that swallow errors (`supplier_quote_repository`, `quote_persistence_support`, `organization_repository`) now have `AppLogger` available to surface them.

## 16. Monitoring — 📋 Manual

- No performance monitoring, health checks, or uptime alerts.
- **To do:** add `firebase_performance` (or equivalent), enable Firebase/GCP monitoring dashboards and alerting on Firestore usage, auth errors, and Crashlytics crash-free rate.

## 17. Backups / data durability — ⛔ Absent

- No scheduled Firestore export and **no Point-in-Time Recovery (PITR)**. Only manual `gcloud firestore export` notes exist in docs.
- **To do:** enable Firestore **PITR**, schedule automated exports to a GCS bucket (`gcloud firestore export` via Cloud Scheduler), define retention, and test a restore.

---

## Backend / security (supporting findings)

- ✅ **Firestore rules** (`firestore.rules`, ~1.6k lines): deny-by-default, role-based, **no `allow … : if true`** and no catch-all. Production-grade posture.
- 📋 **Review broad reads:** several collections grant read to any signed-in user — `products`, `catalogProducts`, `supplierDirectory` (intended public), but also `quoteRequestItems` (`:1563`) and `supplierQuoteItems` (`:1612`). Confirm these line-item reads don't leak across tenants.
- ✅ **Storage rules** locked down (public read only for `catalog/images/**`).
- 📋 **Rules tests are text assertions:** the Dart "security" tests only assert `firestore.rules` *contains* substrings — they don't exercise enforcement. Real emulator tests exist only in `test/firestore/` (one scenario). Expand `@firebase/rules-unit-testing` coverage for critical paths.
- 📋 **Cloud Functions:** none implemented — invitation email is a plan (`tools/functions/README.md`); the app currently copies the invite link.
- 📋 **Lint strictness:** `analysis_options.yaml` downgrades several real signals to `ignore` (e.g. `use_build_context_synchronously`, `deprecated_member_use`, `await_only_futures`). Consider re-enabling incrementally.

## iOS / Android specifics (verified OK)

- ✅ iOS permission usage strings: none needed (no camera/photo/file pickers in the dependency set).
- ✅ iOS ATS defaults to HTTPS-enforced; Android manifest requests only `INTERNET`.
- 📋 iOS `DEVELOPMENT_TEAM` not set — configure signing team in Xcode before archiving. `CFBundleName` is still `construction_rfq` (display name is correctly Hebrew).
- 📋 Android: enable R8/`minifyEnabled` + `shrinkResources` and add ProGuard keep rules for release.

---

## What this pass changed (safe, non-breaking)

Added: `lib/config/app_config.dart`, `lib/config/feature_flags.dart`, `lib/services/crash_reporter.dart`, `lib/utils/app_logger.dart`, `lib/utils/legal_content.dart`, `lib/screens/profile/about_legal_screen.dart` (route `/about` + Profile tile), `.github/workflows/ci.yml`, `LICENSE`, `docs/legal/PRIVACY_POLICY.md`, `docs/legal/TERMS_OF_SERVICE.md`, `android/key.properties.example`, tests for the new modules. Branded `web/manifest.json`. Wired the crash-reporter seam into bootstrap error handling and a boot log into `main.dart`.

Deliberately **not** auto-changed (need a human decision or external asset/credential): Gradle DSL/app-id reconciliation, release signing, adding native Firebase plugins (analytics/crashlytics/performance), icons/splash art, rotating committed QA secrets, Firestore backups/PITR, and firestore.rules broad-read review.
