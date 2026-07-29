# Closed Beta Readiness Checklist

**Product:** Construction RFQ marketplace (Flutter, Hebrew/RTL, Firebase)
**Branch:** `feature/full-project-centric-redesign`
**Review date:** 2026-07-27
**Method:** Code-frozen audit of onboarding, support, documentation, legal, analytics, crash reporting, operations, monitoring, release process, backups, restore, incident recovery, admin operations, and UX. Findings verified against current code, not against prior review notes or commit messages alone.

This checklist supersedes the 2026-07-24 beta-readiness review for items it re-verified. Several items flagged Critical on 2026-07-24 (legal placeholders, support dead-ends, invitation email-verification UI, tender-bid doc-id rule mismatch, admin bootstrap enforcement) are **confirmed fixed** below and removed from the open list. New/confirmed-still-open items are below, grouped by severity.

Legend: 📁 = file/doc reference, ⛔ = blocks real company use, no workaround.

---

## CRITICAL — must fix or explicitly accept before any real company touches this

| # | Area | Finding | Reference |
|---|------|---------|-----------|
| C1 | Analytics/Crash Reporting | `FEATURE_ANALYTICS` and `FEATURE_CRASH_REPORTING` are `bool.fromEnvironment` with **no default value** → both `false` unless a build explicitly passes `--dart-define=...=true`. No build script, CI job, or flavor in the repo sets either flag. A default closed-beta build ships **fully blind** to crashes and usage, exactly as before the wiring commits — the code is ready, the build config is not. | `lib/config/feature_flags.dart:38-39`, `docs/CRASH_REPORTING_SETUP.md`, `docs/ANALYTICS_SETUP.md` |
| C2 | Crash Reporting | Native Firebase config files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are absent, and Crashlytics is not enabled in the Firebase console. Even with the flag on, init failure is caught silently and falls back to `NoOpCrashReporter` — no error, no signal that it isn't working. | `lib/services/crashlytics_crash_reporter.dart:74-84`, `docs/CRASH_REPORTING_SETUP.md` items 1-3 |
| C3 | Release Process | Hardcoded weak passwords (`123123`, `Qa123456!`) are compiled into the **release app binary**, not just dev tooling — shown as UI helper text in the admin panel. Same credentials appear in `tools/admin/admin_onboarding.js` (used to create real accounts) with no forced-reset-on-first-login. | `lib/screens/admin/admin_management_panel.dart:194,229,295`, `tools/admin/admin_onboarding.js:22-23`, `RELEASE_CHECKLIST.md:61` |
| C4 | Release Process / Operations | Single shared Firebase project for dev/QA/prod (`construction-rfq-itay-20-2eee0`) — no environment separation anywhere in `firebase.json` or build config. QA smoke tests, seed data, and the hardcoded test accounts above co-mingle with real customer data in the same Firestore. No safe blast radius for a bad QA run. | `firebase.json`, `RELEASE_CHECKLIST.md:10` |
| C5 | Release Process | Android release build type is signed with the **debug keystore** (`signingConfig = signingConfigs.debug`). Store submission is not possible in this state; only informal sideload/internal-test distribution works. | `android/app/build.gradle`, `RELEASE_CHECKLIST.md` #1 |
| C6 | Backups / Restore | No Firestore PITR, no scheduled export, no backup of any kind exists. Confirmed unchanged — still an owner/console action, not implemented. Any accidental bulk delete or bad write against real customer data is **permanent**. | `docs/PRE_BETA_OPERATIONS.md:11-12`, `RELEASE_CHECKLIST.md` §17 |
| C7 | Backups / Incident Recovery | RFQ delete is allowed with no check for child `supplierQuotes`, orphaning them permanently with zero backup to recover from. Combined with C6, there is no path back from a customer accidentally deleting an RFQ that already has quotes. | `firestore.rules:1638` |
| C8 | Admin Operations | Only user-creation tooling (`tools/admin/admin_onboarding.js`) provisions real accounts with the same hardcoded weak passwords as C3, with no forced password reset flow. | `tools/admin/admin_onboarding.js:22-23,182,202` |
| C9 | Admin Operations / Support | No impersonation / "sign in as user" capability exists anywhere in the app (`grep` for "impersonat" returns zero hits). When a beta user gets stuck, the only way to see what they see is a support person asking them to screen-share, or an engineer inspecting Firestore/Auth console directly. | `lib/` (absence confirmed) |

---

## HIGH — will visibly hurt trust or create real operational pain; should fix before broad beta, acceptable to ship with an explicit workaround for a small, hands-on first cohort

| # | Area | Finding | Reference |
|---|------|---------|-----------|
| H1 | Onboarding/UX | New users land on a blank dashboard with no tutorial or "get started" guidance, and can immediately click into reachable stub tabs ("פרויקטים", "תפקידי רכש", "הגדרות אישורים" in company screens; "ניהול בקשות והזמנות", "הגדרות מערכת" in the admin cockpit) that just say "יתווסף בהמשך" (coming soon). | `lib/screens/contractor/contractor_company_screen.dart:90-102`, `lib/screens/supplier/supplier_company_screen.dart:88-100`, `lib/screens/admin/admin_system_cockpit.dart:96,101` |
| H2 | Onboarding/UX | Submitting an RFQ while offline can hang indefinitely on "שולח בקשה..." with no timeout or cancel action — not a false success, but a real user could mistake it for a freeze. | `lib/screens/customer/cart_screen.dart:184-310` |
| H3 | Support | Support/contact action is correctly wired end-to-end, but `AppConfig.supportEmail` defaults to **empty** — unless the release build passes a real address via `--dart-define`, users get a clipboard-copy fallback ("share this with whoever invited you") instead of a working contact channel. This is an honest fallback (no fabricated address), but it's an open ops step. | `lib/config/app_config.dart:79-80`, `docs/PRE_BETA_OPERATIONS.md:16` |
| H4 | Legal | In-app Privacy Policy / Terms of Service correctly pull config values (no more bracket placeholders) but explicitly state they are **beta drafts pending legal review**. Fine for an internal/friendly closed beta; not adequate if a real external company needs to rely on these terms for anything contractual. | `lib/utils/legal_content.dart` |
| H5 | Analytics | `catalogRfqAnalyticsProvider` (item-level catalog/RFQ interaction events: `catalog_selector_opened`, `catalog_item_selected`, `manual_item_added`, `supplier_exact_quote`, etc.) is still hardcoded NoOp/Debug in release, unlike the main `appAnalyticsProvider` funnel — this is documented as deliberately out of scope in `docs/ANALYTICS_RELEASE.md`, but means a real chunk of product-usage signal is unmeasured even once C1/C2 are resolved. | `lib/analytics/catalog_rfq_analytics.dart:39-43` |
| H6 | Release Process | No build flavors (dev/staging/prod) for Android or iOS, and CI only runs analyze/test/`build web --release` — no signed Android/iOS release job exists. There is no automated path to a distributable store artifact today. | `RELEASE_CHECKLIST.md` §7-8, `.github/workflows/ci.yml` |
| H7 | Release Process | Conflicting Gradle DSL (dead `.gradle.kts` files alongside active Groovy) and three disagreeing application IDs across Android/iOS/dead-kts. Must be reconciled before any store submission or reliable Firebase app-id binding. | `RELEASE_CHECKLIST.md` #2-3 |
| H8 | Release Process | `google-services.json` is git-ignored/absent while the Gradle plugin that requires it is applied — Android build likely fails or silently no-ops depending on plugin version (same root cause as C2). | `android/app/build.gradle:5`, `RELEASE_CHECKLIST.md` #4 |
| H9 | Backups / Restore | No restore procedure exists at all, dev or prod. The only related tool (`tool/RESET_FIRESTORE_DEV.md`) is a destructive dev-wipe explicitly scoped away from production, not a restore mechanism. | `tool/RESET_FIRESTORE_DEV.md` |
| H10 | Incident Recovery | No incident-response runbook exists anywhere in `docs/` — no playbook for outage, bad deploy, security incident, or mass data corruption. A real production issue on day 1 would be handled entirely ad hoc. | `docs/` (absence confirmed) |
| H11 | Admin Operations | `blockUser()` remains dead code (unused, unreferenced from any screen) while a separate, parallel `disableUser`/`reactivateUser` path is the one actually wired — duplicate logic risks drifting out of sync. | `lib/services/admin_approval_service.dart:63-72` vs `lib/services/user_approval_service.dart:174-218` |
| H12 | Admin Operations | `approveAccessRequest` never re-checks that a request is still `pending` inside its transaction — two admins (or a double-click) can both approve, or approve an already-withdrawn request, creating duplicate/incorrect membership state. | `lib/services/user_approval_service.dart:54-131` |
| H13 | Admin Operations | Project-assignment fan-out writes happen **after** the approval transaction commits, as separate non-atomic writes with no rollback — a partial failure leaves a user approved/active but missing project assignments, with no in-app way to detect or repair it. | `lib/services/user_approval_service.dart:106-124` |

---

## MEDIUM — noticeable rough edges; fine to launch closed beta with these open, fix during the beta window

| # | Area | Finding | Reference |
|---|------|---------|-----------|
| M1 | Onboarding/UX | Zero accessibility support — no `Semantics(` usage anywhere in the app; no screen-reader labels on icon buttons or custom widgets. | repo-wide (`lib/`) |
| M2 | Legal / Documentation | `docs/legal/PRIVACY_POLICY.md` and `docs/legal/TERMS_OF_SERVICE.md` (labeled the "canonical Markdown source" in code comments) still contain literal placeholders (`[COMPANY LEGAL NAME]`, `[YYYY-MM-DD]`, `[e.g. State of Israel]`, `[age]`) even though the in-app copy is now config-driven — creates drift risk between the doc and the app, especially for the governing-law and minors'-age clauses which exist only in the doc. | `docs/legal/PRIVACY_POLICY.md`, `docs/legal/TERMS_OF_SERVICE.md` |
| M3 | Crash Reporting | Several `auth_service.dart` catch blocks only `debugPrint` (invisible in release) on claims-load / user-lookup / refresh-verification failures — these auth-path errors will never reach Crashlytics even once C1/C2 are fixed. | `lib/services/auth_service.dart:80,129,293` |
| M4 | Crash Reporting | Web builds have no crash coverage by design (no Flutter-web Crashlytics SDK) — documented honestly, not a bug, but worth knowing before promoting the web build for beta use. | `docs/CRASH_REPORTING_SETUP.md` item 6 |
| M5 | Release Process | No store-readiness assets: default Flutter launcher icon/splash screen, iOS `DEVELOPMENT_TEAM` unset, Android R8/minify not enabled. Version still at template default `1.0.0+1`, no CHANGELOG. | `RELEASE_CHECKLIST.md` §§9-13 |
| M6 | Release Process | No runtime kill-switch — feature flags are build-time `--dart-define` only; a bad flag requires a full rebuild/re-release rather than a remote toggle. | `lib/config/feature_flags.dart`, `RELEASE_CHECKLIST.md` §4 |
| M7 | Release Process | Rollback plan exists only for web hosting and Firestore rules (git-tag based); there is no rollback story for a bad native release or for corrupted Firestore data. | `docs/LAUNCH_CHECKLIST.md`, `docs/DEPLOYMENT.md` |
| M8 | Monitoring | No monitoring beyond Crashlytics/Analytics — no `firebase_performance`, no Cloud Monitoring alerts, no uptime checks, no paging. An incident would only surface via user complaints. | `pubspec.yaml` (absence confirmed) |
| M9 | Admin Operations | No in-app way to fix or undo corrupted/orphaned data (ties to C7/H9) — any data repair requires direct Firestore console access by an engineer. Bulk seeding/reset/backfill scripts are also terminal-only, fine for beta scale but not self-serviceable by a business admin. | `lib/screens/admin/*`, `tools/admin/*` |
| M10 | Admin Operations | `PlatformAdmin.bootstrapEmails` (two hardcoded emails) remains live client-side UI-visibility logic — cosmetic only today since `firestore.rules` genuinely enforces admin access server-side via the `platformAdmin` custom claim, but it's a latent trap if anyone later wires it into an authorization decision. | `lib/services/platform_admin.dart:6-9` |
| M11 | Lint / Code Quality | `analysis_options.yaml` ignores `use_build_context_synchronously` and `deprecated_member_use`, reducing CI signal quality — not release-blocking. | `analysis_options.yaml` |

---

## LOW — cosmetic / nice-to-have, non-blocking

| # | Area | Finding | Reference |
|---|------|---------|-----------|
| L1 | Onboarding/UX | Minor "coming soon" strings in lower-traffic secondary flows (cost/report views, permissions editing notice). | `lib/utils/enterprise_hierarchy_presets.dart:129,237`, `lib/widgets/permissions/role_read_only_notice.dart:51` |
| L2 | Documentation | No end-user help/FAQ exists anywhere — every `docs/*.md` file is developer/operator-facing. Acceptable for a hands-on closed beta, a gap for wider rollout. | `docs/` |
| L3 | Admin Operations | Catalog admin tooling is CLI/dev-screen only (expected at this stage for a supplier-catalog import pipeline). | `docs/CATALOG_ADMIN_TOOLS.md`, `lib/screens/dev/catalog_admin_ops_screen.dart` |

---

## Confirmed FIXED since the 2026-07-24 review (no longer open)

- Invitation email-verification gate: `verify_email_screen.dart` + `invite_landing_screen.dart` now correctly route unverified invitees through verify-email before accept, matching `firestore.rules`' `emailVerified()` requirement.
- RFQ draft persistence: scoped SharedPreferences persistence + idempotent `clientOperationId`-keyed submit (no duplicate-RFQ risk on retry); offline banner is honest about "draft saved on device," not a false success.
- Legal placeholders (`[שם החברה]`, `[support@example.com]`) removed from all in-app copy (`lib/utils/legal_content.dart`) — config-driven now.
- Support contact action is wired to a real flow (analytics-tracked, tested) rather than a dead link — see H3 for the remaining config-default gap.
- Platform-admin bootstrap: `firestore.rules` genuinely enforces `platformAdmin`-gated access server-side at ~25 rule sites; the earlier "client-only cosmetic gate" concern is resolved (see M10 for a residual cosmetic-only leftover).
- Tender counter-bid doc-id now uses a deterministic per-version id (`SupplierQuoteDocId.forTenderBid`) matching `firestore.rules`' `supplierQuoteDeterministicDocId` tender branch — the previously-flagged uuid-vs-deterministic-id rule mismatch is resolved in code (`lib/services/quote_service.dart:296-301`, `firestore.rules:1382-1386`). Not re-verified against a live emulator this session.
- Empty states are broadly implemented via a shared `empty_state.dart` widget across catalog/quotes/orders/deliveries/requests — no blank-screen risk found.
- RTL is enforced globally and no locale-toggle bugs were found in this pass.

*Items not independently re-verified this session and carried over from prior reviews (see `docs/KNOWN_LIMITATIONS.md`, memory `data-integrity-review-2026-07-24`): non-procurement customer quote-to-`ordered` transition gating, contractor-approver `notSelected` transition, unbounded `markIncomingRequestsSeenBySupplier` query, InvitationRepository non-atomic `.set()` on accept, duplicate pending invitations. None of these were in this audit's assigned scope (onboarding/support/docs/legal/analytics/crash/ops/monitoring/release/backups/restore/incident-recovery/admin/UX) but should stay on the team's radar.*
