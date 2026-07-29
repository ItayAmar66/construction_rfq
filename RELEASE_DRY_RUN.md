# Release Dry Run — 2026-07-28 (simulating release 2026-07-29)

## Executive Summary

**Verdict: NO-GO.** The app cannot ship to Android or iOS stores tomorrow: Android release builds are signed with the debug keystore and two Gradle files declare different application IDs; iOS has no `Runner.entitlements` file, no signing team, and a bundle ID that matches neither Android value; and both platforms lack `google-services.json`/`GoogleService-Info.plist`, which also silently disables Crashlytics/Analytics regardless of feature flags. Even a web-only launch is blocked — analytics and crash reporting default to **off** at build time (no CI job passes the enabling `--dart-define`s), CI never deploys anything to Firebase Hosting, and the legal docs still contain placeholder text. This is consistent with the repo's own `NO_GO_CHECKLIST.md` and `PRODUCTION_READINESS_SCORECARD.md`.

**Issue counts:** Critical: 9 | High: 9 | Medium: 7 | Low: 4

## Findings by Area

### Android Release
Current state: `android/app/build.gradle.kts` sets `applicationId = "com.construction.construction_rfq"`, Java 17, SDK versions from Flutter defaults. `android/app/build.gradle` (Groovy, also present in the repo) sets `applicationId = "com.construction.rfq"`, hardcodes `minSdk = 23`, uses Java 8, and applies the `com.google.gms.google-services` plugin. Both files coexist; Gradle will resolve to one of them (Groovy typically wins over `.kts` when both are present), leaving the other as dead-but-committed and misleading. Release `buildTypes` in both files use the debug signing config (`signingConfig = signingConfigs.debug` / `signingConfigs.getByName("debug")`). No ProGuard/R8 minification is configured.
- Critical: Two build files declare different `applicationId`s (`com.construction.construction_rfq` vs `com.construction.rfq`) — undefined which ships; risk of wrong package ID or mismatch against the Firebase console app registration.
- Critical: Release build signs with the debug keystore — Play Store rejects debug-signed bundles; no release signing exists at all.
- Critical: The Groovy file applies `com.google.gms.google-services` but `google-services.json` is absent from the repo — `flutter build apk/appbundle --release` will fail on that path.
- Medium: No `minifyEnabled`/ProGuard/R8 configuration — ships unshrunk, unobfuscated code.
- Low: Java/SDK target diverges between the two files (17 vs 8) — a symptom of the duplicate-file problem.
- Recommendation: Delete one of the two Gradle DSLs, reconcile the applicationId with the Firebase console, generate a real upload keystore + `key.properties`, wire `signingConfigs.release`.

### iOS Release
Current state: `ios/Runner/Info.plist` sources `CFBundleShortVersionString`/`CFBundleVersion` from `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)` (correct pattern). `ios/Runner.xcodeproj/project.pbxproj` shows `PRODUCT_BUNDLE_IDENTIFIER = com.construction.constructionRfq` for the Runner target (a third, distinct ID from both Android values) and `com.construction.constructionRfq.RunnerTests` for tests. `CODE_SIGN_STYLE = Automatic`, no `DEVELOPMENT_TEAM` found. `ios/Runner/Runner.entitlements` does not exist in the repo at all. `ios/Podfile` is present.
- Critical: No `GoogleService-Info.plist` in the repo — Firebase cannot initialize on a native iOS build.
- High: No `DEVELOPMENT_TEAM` set with `CODE_SIGN_STYLE = Automatic` — Xcode cannot produce a signed archive without manual setup.
- High: Bundle ID (`com.construction.constructionRfq`) matches neither Android applicationId (`com.construction.construction_rfq` nor `com.construction.rfq`) — cross-platform Firebase app registration and any universal-link/App-Links config will be inconsistent.
- Medium: `Runner.entitlements` is missing entirely — any entitlement-requiring capability (push, associated domains, etc.) is unconfigured.
- Recommendation: Reconcile bundle ID with Android, configure a real signing team, add `GoogleService-Info.plist`, confirm whether entitlements are needed before archiving.

### Web Release
Current state: `web/index.html` has real meta tags, description, and icon references (not template placeholders). `web/manifest.json` is fully populated: name, short_name, theme/background colors, icons at 192/512 plus maskable variants. `firebase.json` hosting config points `public` at `build/web` with an SPA rewrite (`**` → `/index.html`) — standard and correct. It also embeds FlutterFire app IDs for android/ios/macos/web/windows, all under project `construction-rfq-itay-20-2eee0`.
- Low: Firebase emulator UI is disabled (`"ui": {"enabled": false}`) in `firebase.json` — fine for CI, less convenient for local debugging; not a release blocker.
- Recommendation: Web hosting config itself is release-ready; the actual gap is the missing CI deploy step (see Rollback below), not the static config.

### Signing
Current state: Android is debug-signed only with no keystore/`key.properties` in the repo; `.gitignore` correctly excludes `**/android/key.properties` and `**/*.jks` (good hygiene, but nothing real to protect yet). iOS uses automatic signing with no team ID configured and no entitlements file.
- Critical: Neither platform has a real release signing identity — this alone blocks both store submissions.
- Recommendation: Generate an Android upload keystore and enroll in Play App Signing; configure an Apple Developer team and provisioning for iOS.

### Build Numbers/Version
Current state: `pubspec.yaml` → `version: 1.0.0+1`, the untouched Flutter template default. iOS derives its version/build from the same Flutter vars, which is correct in principle, but `project.pbxproj` also contains a separate literal `MARKETING_VERSION = 1.0;` / `CURRENT_PROJECT_VERSION = 1;` pair (likely a non-Runner target) worth confirming doesn't leak into the shipped app.
- High: Version is still `1.0.0+1` — no evidence it was bumped for this release; shipping the literal scaffold version undermines update/rollback tracking on both stores.
- Low: Redundant hardcoded version fields alongside the Flutter-derived vars in `project.pbxproj` — confirm which target they apply to.
- Recommendation: Bump `pubspec.yaml` version before building; verify only Flutter-derived vars apply to the Runner target.

### Firebase
Current state: `firebase.json`, `.firebaserc` (single project alias `construction-rfq-itay-20-2eee0`, no staging alias), `firestore.rules` (1763 lines; extensive `isSignedIn()`/`isPlatformAdmin()` gating, several `allow write: if false` locked collections — reads as deliberately hardened, not permissive test rules), `firestore.indexes.json` (212 lines), `storage.rules` (14 lines: public read only for `catalog/images/**`, deny-all elsewhere — tight). No native config files (`google-services.json`/`GoogleService-Info.plist`) present anywhere in the repo.
- Critical: No native Firebase config files present — even a correctly flag-enabled build cannot initialize Crashlytics/Analytics/native Firebase paths.
- High: Single Firebase project for dev/staging/prod — no infrastructure-level environment isolation; separation exists only at the app level via `AppConfig`/dart-defines.
- Recommendation: Provision native config files securely (not via git) per platform; evaluate a second Firebase project for non-prod before scaling past closed beta.

### Crashlytics
Current state: `firebase_crashlytics: ^4.3.10` is a real dependency in `pubspec.yaml`. `lib/services/crashlytics_crash_reporter.dart` implements a genuine `CrashReporter` calling `FirebaseCrashlytics.instance` (`recordError`, `recordFlutterError`, `setUserIdentifier`, `log`), including message redaction via `CrashReportRedaction`. `lib/utils/bootstrap_error_handling.dart`'s `BootstrapErrorHandling.install()` wires `FlutterError.onError` and `PlatformDispatcher.instance.onError` unconditionally in `main.dart`. `shouldEnableCrashlytics()` correctly excludes web (no Crashlytics web SDK) and requires `FeatureFlags.crashReportingEnabled`.
- Critical: `FEATURE_CRASH_REPORTING` is `bool.fromEnvironment('FEATURE_CRASH_REPORTING')` with **no default value**, i.e. it is `false` unless explicitly passed. `.github/workflows/ci.yml` only builds web with `--dart-define=APP_ENV=prod` — nothing ever sets this flag. A default release build ships completely blind to crashes despite fully correct code.
- High: Even with the flag on, the missing native config file (see Firebase) means Crashlytics still can't initialize on Android/iOS.
- Recommendation: Add a real production build/CI job passing `--dart-define=FEATURE_CRASH_REPORTING=true`, install native config files, and verify with a physical-device test crash before shipping.

### Analytics
Current state: `firebase_analytics: ^11.6.0` in `pubspec.yaml`. `lib/analytics/app_analytics.dart` wires `resolveAppAnalytics()`, used in `main.dart`, gated by `FeatureFlags.analyticsEnabled`. Docs (`docs/ANALYTICS_SETUP.md`, `docs/ANALYTICS_RELEASE.md`) describe a 16-event closed-beta funnel already instrumented.
- Critical: Same root cause as Crashlytics — `FEATURE_ANALYTICS` defaults `false` and nothing in the repo's build/CI turns it on, so a default build ships with zero product analytics.
- High: No native config files means events cannot land even with the flag enabled.
- Medium: Per `RELEASE_CHECKLIST.md`, a separate `catalogRfqAnalyticsProvider` for item-level catalog events is hardcoded no-op in production — a known, smaller-scope gap distinct from the app-level funnel above.
- Recommendation: Same fix as Crashlytics — real build pipeline that sets the flag, native config files, DebugView verification pre-launch.

### Monitoring
Current state: Beyond Crashlytics (crash) and Analytics (product events), no `firebase_performance`, no Sentry, and no uptime/alerting configuration was found in `pubspec.yaml` or the codebase. Error hooks (`FlutterError.onError`/`PlatformDispatcher.onError`) exist via `BootstrapErrorHandling` but forward only to Crashlytics, which is off by default.
- High: No performance monitoring or alerting exists beyond crash reporting, and that path is itself disabled by default — there is currently no real-time signal if the app breaks post-launch.
- Recommendation: At minimum ship with the Crashlytics flag enabled and console alert thresholds configured; consider `firebase_performance` for a later iteration.

### Rollback
Current state: `.github/workflows/ci.yml` defines one job graph: `analyze-test` → `build-web` (`flutter build web --release --dart-define=APP_ENV=prod`). No deploy job exists anywhere in `.github/workflows/` (no `firebase deploy`, no store upload step). Git tags exist (`v1`, `v2.1`, `v2.2`, `v3.0`) suggesting some prior release discipline, but nothing ties a tag to a deployable artifact or documents reverting a bad release.
- High: CI never actually deploys — a green run doesn't put a build in front of users, so there's correspondingly no defined rollback path because there's no deploy step to roll back.
- Medium: No rollback runbook found (no `ROLLBACK.md` or equivalent).
- Recommendation: Add a deploy job (e.g. `firebase deploy --only hosting,firestore:rules`) gated on tags/main; write a short rollback runbook (hosting version rollback, rules rollback via git history, store "halt rollout" steps).

### Backups
Current state: `tools/admin/backups` exists but only contains `launch_reset_*` directories (test-data reset artifacts from prior sessions), not a backup/export mechanism. No scheduled Firestore export config, no Cloud Scheduler/Cloud Function export job, no `gcloud firestore export` script found anywhere in the repo.
- High: No Firestore backup/export strategy — a bad migration or accidental bulk-delete has no confirmed recovery path.
- Recommendation: Enable Firestore PITR or scheduled exports to GCS via Cloud Scheduler, and document the restore procedure.

### Release Notes
Current state: No `CHANGELOG.md` or dedicated release-notes file at the repo root. Commit history is descriptive, but there is no curated, user/QA-facing summary of what changed for this branch.
- Medium: No changelog — reviewers/testers/store listings have no prepared summary of what's new in this build.
- Recommendation: Add a lightweight `CHANGELOG.md`, at least for beta/release milestones.

### Privacy Policy
Current state: `lib/screens/profile/about_legal_screen.dart` links to in-app `LegalContent.privacyPolicy` and a support-contact action (`lib/utils/support_contact.dart`). Backing docs exist at `docs/legal/PRIVACY_POLICY.md`. Per the pre-existing `RELEASE_OPERATIONS_REPORT.md` (cross-checked, not re-verified line-by-line here), this doc still contains the literal placeholder `[support@example.com]` in multiple places.
- High: Privacy policy content contains unresolved placeholder text and is not confirmed hosted at a stable public URL — required for store listings.
- Recommendation: Finalize placeholder text, host at a stable public URL, link from both the app and store listings.

### Terms
Current state: Same in-app surface (`about_legal_screen.dart` → `LegalContent.termsOfService`) and same doc pair (`docs/legal/TERMS_OF_SERVICE.md`), with the same placeholder-text issue reported by `RELEASE_OPERATIONS_REPORT.md`.
- High: Same unresolved placeholder text as Privacy Policy.
- Low: `LICENSE` file reportedly still has an unreplaced `[COPYRIGHT HOLDER]` placeholder (per cross-reference) — low priority unless the repo is shared externally.
- Recommendation: Same as Privacy Policy — finalize and host before store submission.

### Deployment Docs
Current state: No `DEPLOY.md` at repo root. `RELEASE_CHECKLIST.md` (143 lines) and `RELEASE_OPERATIONS_REPORT.md` (108 lines) exist and are substantive but function as audit/status documents, not step-by-step deploy runbooks. No doc describes how a human actually ships a build to stores or hosting today.
- Medium: No actionable deploy runbook — release execution knowledge is implicit in audit docs rather than a repeatable procedure.
- Recommendation: Convert the "to do" items already itemized in `RELEASE_CHECKLIST.md` into an actual `DEPLOY.md` with exact commands per platform.

### Support
Current state: `lib/utils/support_contact.dart` and `about_legal_screen.dart` wire a working in-app support action. `AppConfig.supportEmail` defaults to an **empty string** unless set via `--dart-define=SUPPORT_EMAIL=...`; when empty, the UI falls back to a clipboard-copy flow instead of a working mailto/contact link.
- High: No real support email configured by default, and nothing in build/CI sets one — a shipped default build gives users a "copy this and find someone" fallback instead of a working support channel.
- Recommendation: Decide the real support address and pass it via `--dart-define=SUPPORT_EMAIL=...` in the actual release build command.

### Assets/Icons/Splash
Current state: Android launcher icons present at all mipmap densities (mdpi through xxxhdpi, 442–1443 bytes — small but not necessarily placeholder, simple icon art is often this size). iOS `AppIcon.appiconset` has a full slot set (20x20 through 1024x1024) populated. No `flutter_native_splash` or `flutter_launcher_icons` dependency in `pubspec.yaml` — if these are branded assets, generation happened outside this repo's build config.
- Medium: Cannot visually confirm from file listing alone whether icons are final brand art or still the Flutter default template icon — needs a visual check before submission since store review commonly rejects the default Flutter icon.
- Low: No `flutter_native_splash` config means no codified splash-generation step.
- Recommendation: Visually open and verify the icon PNGs before submission; add `flutter_native_splash` config if a branded, automated launch screen is wanted.

## Full Issue List (sorted Critical → Low)

| Severity | Area | Issue | File/Location | Recommendation |
|---|---|---|---|---|
| Critical | Android Release | Two Gradle files declare different `applicationId`s | `android/app/build.gradle`, `android/app/build.gradle.kts` | Delete one DSL, reconcile app ID with Firebase console |
| Critical | Android Release | Release build signs with the debug keystore | `android/app/build.gradle` (`signingConfig = signingConfigs.debug`), `build.gradle.kts` | Generate upload keystore + `key.properties`, wire `signingConfigs.release` |
| Critical | Android Release | `google-services` plugin applied but `google-services.json` absent | `android/app/build.gradle:5` | Add gitignored native config file or remove plugin |
| Critical | iOS Release | No `GoogleService-Info.plist` present | `ios/Runner/` | Add gitignored native config file before native builds |
| Critical | Signing | No real release signing identity on either platform | Android debug-signed; iOS `CODE_SIGN_STYLE=Automatic`, no team | Set up Play upload keystore + Apple Developer team signing |
| Critical | Firebase | No native Firebase config files anywhere in repo | android/, ios/, macos/ | Provision native config files securely (not via git) |
| Critical | Crashlytics | `FEATURE_CRASH_REPORTING` defaults false; no build/CI job enables it | `lib/config/feature_flags.dart`, `.github/workflows/ci.yml` | Add release build/CI job passing `--dart-define=FEATURE_CRASH_REPORTING=true` |
| Critical | Analytics | `FEATURE_ANALYTICS` defaults false; no build/CI job enables it | `lib/config/feature_flags.dart`, `.github/workflows/ci.yml` | Add release build/CI job passing `--dart-define=FEATURE_ANALYTICS=true` |
| Critical | Monitoring | No working crash/error visibility by default (compounds Crashlytics gap) | n/a | Ship with flags on plus console alerts before any release |
| High | iOS Release | No `DEVELOPMENT_TEAM` set with `CODE_SIGN_STYLE=Automatic` | `ios/Runner.xcodeproj/project.pbxproj` | Configure a real signing team |
| High | iOS Release | Bundle ID differs from both Android applicationIds | pbxproj `com.construction.constructionRfq` vs Android `com.construction.rfq`/`construction_rfq` | Reconcile a single canonical app ID across platforms |
| High | Build Numbers/Version | `pubspec.yaml` version still `1.0.0+1` template default | `pubspec.yaml` | Bump version before building for release |
| High | Firebase | Single Firebase project for dev/staging/prod, no isolation | `.firebaserc`, `firebase.json` | Consider a second project for non-prod before scaling |
| High | Crashlytics/Analytics | Native config absence blocks reporting even if flags are on | android/, ios/ | Provision native config files (tracked together with Firebase Critical) |
| High | Rollback | CI builds web but never deploys; no deploy job exists | `.github/workflows/ci.yml` | Add `firebase deploy` job gated on tag/main |
| High | Backups | No Firestore export/backup scheduling found | `tools/admin/backups` (test-data only) | Enable Firestore PITR or scheduled GCS exports |
| High | Privacy Policy | Placeholder text `[support@example.com]` reported still present | `docs/legal/PRIVACY_POLICY.md` | Finalize and host before store submission |
| High | Terms | Placeholder text `[support@example.com]` reported still present | `docs/legal/TERMS_OF_SERVICE.md` | Finalize and host before store submission |
| High | Support | `SUPPORT_EMAIL` defaults empty; falls back to clipboard-copy | `lib/config/app_config.dart` | Pass real `--dart-define=SUPPORT_EMAIL=...` in the release build |
| Medium | Android Release | No ProGuard/R8 minification configured | `android/app/build.gradle*` | Enable `minifyEnabled`/shrink rules for release |
| Medium | iOS Release | `Runner.entitlements` file missing entirely | `ios/Runner/` | Add if any entitlement-requiring capability is used |
| Medium | Analytics | `catalogRfqAnalyticsProvider` item-level events hardcoded no-op in prod | per `RELEASE_CHECKLIST.md` §2 | Wire the prod branch of the provider if item-level events are wanted at launch |
| Medium | Monitoring | No performance monitoring/alerting beyond (currently off) Crashlytics | n/a | Consider `firebase_performance`; configure console alert thresholds |
| Medium | Rollback | No documented rollback runbook | n/a | Write a short rollback procedure for hosting/rules/store halts |
| Medium | Release Notes | No `CHANGELOG.md` exists | repo root | Add a lightweight changelog for release milestones |
| Medium | Deployment Docs | No actionable deploy runbook, only audit-style docs | repo root | Convert `RELEASE_CHECKLIST.md` action items into a `DEPLOY.md` |
| Medium | Assets/Icons/Splash | Cannot confirm icons are final brand art vs default from listing alone | `android/app/src/main/res/mipmap-*`, `ios/.../AppIcon.appiconset` | Visually verify icon art before submission |
| Low | Android Release | Java/SDK config diverges between the two Gradle files (17 vs 8) | `android/app/build.gradle*` | Resolves once duplicate file is removed |
| Low | Build Numbers/Version | Redundant hardcoded `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` alongside Flutter vars | `ios/Runner.xcodeproj/project.pbxproj` | Confirm which target these apply to; remove if stray |
| Low | Terms | `LICENSE` file reportedly has unreplaced `[COPYRIGHT HOLDER]` placeholder | `LICENSE` | Fix if repo is shared externally |
| Low | Assets/Icons/Splash | No `flutter_native_splash` config for automated splash generation | `pubspec.yaml` | Add if a branded, codified splash step is desired |
| Low | Web Release | Firebase emulator UI disabled in config (local dev convenience only) | `firebase.json` | Non-blocking; enable locally as needed |
