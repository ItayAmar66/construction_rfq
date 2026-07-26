# Crash reporting (Firebase Crashlytics) — setup status

## Done in code (this repo)

- `CrashReporter` abstraction (`lib/services/crash_reporter.dart`) is fed by a
  single choke point: `BootstrapErrorHandling.install()`
  (`FlutterError.onError` + `PlatformDispatcher.instance.onError`) and
  `AppLogger.error(...)`.
- `lib/services/crashlytics_crash_reporter.dart` implements that abstraction
  on top of `firebase_crashlytics`, with:
  - `shouldEnableCrashlytics(...)` — pure on/off rule: requires the
    `FEATURE_CRASH_REPORTING` build flag, a real (non-demo) Firebase session,
    and a **non-web** platform (Crashlytics has no Flutter-web SDK — web
    stays on `NoOpCrashReporter` regardless of the flag).
  - `resolveCrashReporter(...)` — initializes Crashlytics only when the rule
    above holds; any initialization failure is caught and falls back to
    `NoOpCrashReporter`, so crash-reporting setup can never block app startup.
  - Log messages/`reason` strings are passed through
    `CrashReportRedaction.redact` (masks emails and long opaque tokens —
    auth/session/invite ids) before leaving the device. Defense-in-depth only;
    call sites should still avoid logging secrets outright.
- Wired in `lib/main.dart` before `runApp`, reading the flag from
  `FeatureFlags.fromEnvironment()` (already-existing scaffold, previously
  unused anywhere in the app).
- Unit-tested: `test/crash_reporting_selection_test.dart` (on/off matrix,
  redaction, NoOp safety).

**Not verified this session** (no physical device / native build available
in this environment): that a real crash on Android/iOS actually reaches the
Firebase console. The Dart-side wiring is correct and testable, but native
Crashlytics also needs platform project files that aren't in this repo yet
(see below) — until those exist, `resolveCrashReporter` will still try to
initialize and then silently fall back to `NoOpCrashReporter` on failure
(logged via `debugPrint` in debug builds only).

## Still required — owner action, not verifiable from code

1. **Enable Crashlytics in the Firebase console** for the project
   (`construction-rfq-itay-20-2eee0` per prior review notes) — Crashlytics
   must be turned on per-project before any data will appear, even once the
   app sends it.
2. **Android**: add `google-services.json` to `android/app/` and apply the
   Google Services + Crashlytics Gradle plugins in
   `android/build.gradle` / `android/app/build.gradle`. Neither file exists
   in this repo as of this change — without them, the native Android
   Crashlytics SDK won't initialize and `resolveCrashReporter` will fall back
   to NoOp even with the flag on.
3. **iOS**: add `GoogleService-Info.plist` to `ios/Runner/` and run
   `pod install` so the Crashlytics iOS SDK links. Also not present in this
   repo yet.
4. **Build flag**: ship builds with
   `--dart-define=FEATURE_CRASH_REPORTING=true` (staging/prod only — leave it
   off for local/dev builds, matching the existing `FeatureFlags` pattern).
5. **Verify end-to-end** once 1–4 are done: trigger a real crash on a test
   device/build and confirm it appears in the Firebase console within a few
   minutes (Crashlytics can lag on first-ever event per app install).
6. **Web**: Crashlytics has no coverage — errors in the web build still only
   reach `AppLogger`/`debugPrint`. If web crash visibility is required for
   beta, that needs a different backend (e.g. Sentry, which does support
   Flutter web) as a follow-up, not part of this change.
