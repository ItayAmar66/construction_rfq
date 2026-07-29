# Production Readiness Scorecard — construction_rfq

**Project:** Construction RFQ marketplace (Flutter, Hebrew/RTL, Firebase)
**Branch:** `feature/full-project-centric-redesign`
**Date:** 2026-07-28
**Method:** Synthesis of seven prior independent reviews — no new code inspection was performed for this scorecard. Sources: `RELEASE_OPERATIONS_REPORT.md` (2026-07-27), `PERFORMANCE_REPORT.md` (2026-07-27), `RED_TEAM_REPORT.md` (2026-07-27), `FIRST_IMPRESSION_AUDIT.md` (2026-07-27), `CLOSED_BETA_CHECKLIST.md` (2026-07-27), `GO_CHECKLIST.md`, `NO_GO_CHECKLIST.md` (2026-07-27), `docs/PRE_BETA_OPERATIONS.md`.

Scores reflect **closed-beta readiness for a small, trusted, hands-on cohort** — not public/app-store readiness, which is explicitly a later gate per `GO_CHECKLIST.md`.

---

## Architecture — 72/100

**Strengths:** Clean layering (repositories → services → Riverpod providers → screens); consistent patterns for batched writes, chunked `whereIn` lookups, and cursor-based pagination where implemented (`AdminRepository`, catalog search). Feature flags (`FeatureFlags.fromEnvironment()`) cleanly separate optional subsystems (analytics, crash reporting).

**Remaining gaps:** No backend API or Cloud Function layer at all — Firestore rules are the *entire* authorization boundary (Red Team, architecture note). No environment separation (single Firebase project for dev/QA/prod). Legacy `quoteRequestItems`/`supplierQuoteItems` collections still live in rules despite being unused by any write path. Dead/duplicate code paths found (unwired catalog repository, `blockUser()` vs `disableUser()`).

**Required actions:** Decide on second Firebase project for environment isolation (owner decision, not a code fix). Purge legacy item collections in production. Reconcile duplicate admin user-state logic (`H11`, `CLOSED_BETA_CHECKLIST.md`).

---

## Security — 78/100

**Strengths:** Red Team review found and **fixed** two High and two Medium findings this cycle: cross-user RFQ draft carryover on shared sessions, RFQ resubmit forging `approvedQuoteId`/`supplierIdsResponded` via the update path, unscoped legacy-collection reads, and unbounded invitation expiry. All fixes verified against 79 emulator rules tests + a rules dry-run deploy. Storage rules are deny-by-default and conservative (no upload surface to attack at all today).

**Remaining gaps:** Org enumeration + PII leak to unapproved accounts (Low-Moderate, needs product decision on scoping). Project-deletion grace period is client-enforced only (Low, no real payoff until a purge job exists). Hardcoded weak QA/admin passwords (`123123`, `Qa123456!`) compiled into the release binary and used by the real account-onboarding script, with no forced reset (Critical per `CLOSED_BETA_CHECKLIST.md` C3/C8).

**Required actions:** Rotate/remove hardcoded passwords and add forced-reset-on-first-login (code + ops). Product decision on org-list PII scoping for unapproved accounts. Purge pre-migration legacy-collection documents in production (owner script exists: `tools/admin/manual_qa_reset.js`).

---

## Firestore — 75/100

**Strengths:** Rules are the real, actively-tested authorization boundary (not UX theater) — verified via 79 passing emulator tests plus a dry-run deploy this cycle. 22 composite indexes defined and internally consistent with query shapes; a missing `auditEvents` index was found and fixed this pass. Chunked `whereIn`, batched writes (≤450/batch), server-side count aggregates in `AdminRepository` are all solid, reusable patterns.

**Remaining gaps:** No PITR, no scheduled export — zero backup of any kind (Critical, `C6`). RFQ delete has no check for orphaned child `supplierQuotes` (Critical, `C7`) — combined with no backups, this is unrecoverable data loss from an ordinary user action. No TTL policy on `invitations`/`accessRequests`. Index deploy/build status on the live project is unverified (console-only, out of session scope).

**Required actions (owner):** Enable PITR, set up scheduled export, run `firebase deploy --only firestore:indexes` and confirm all indexes show "Enabled." **Required action (code):** block or check for orphaned quotes before RFQ delete.

---

## Permissions — 82/100

**Strengths:** Per memory (`permissions-overhaul-status`) this is a feature-complete workstream through Phase 5. `platformAdmin` is a genuine server-side custom claim, enforced at ~25 rule sites, not a client-side gate (confirmed fixed since 2026-07-24 review). `EffectivePermissions` and rules are consistently aligned for the access paths audited by Red Team.

**Remaining gaps:** `approveAccessRequest` doesn't re-check `pending` status inside its transaction — double-approval race (`H12`). Project-assignment fan-out writes happen non-atomically after the approval transaction commits, with no rollback on partial failure (`H13`). `PlatformAdmin.bootstrapEmails` remains a latent client-side trap if ever wired into an actual authorization decision (cosmetic today, `M10`).

**Required actions:** Fix the `approveAccessRequest` transaction race and the non-atomic project-assignment fan-out (both code fixes, not deployed this pass). Agree on a manual single-admin-at-a-time process for the beta window in the interim.

---

## Performance — 70/100

**Strengths:** A structured four-part audit (Firestore, catalog search, rendering, offline/network) found and fixed 9 issues this pass: missing `auditEvents` index, serial→parallel org/membership fetch, unbounded Firestore cache, un-debounced draft persistence, duplicate quote-count listeners, eager list rendering in 4 workspace tabs, sequential→batched assignment writes, unbounded `fetchPendingForOrg`, sequential→parallel `whereIn` chunking. Solid underlying patterns already exist to generalize from (`AdminRepository`'s count-aggregate usage, chunked batch writes, debounced search).

**Remaining gaps:** Two **Critical**, unfixed, design-level issues: supplier "incoming requests" opens 4 unbounded platform-wide listeners with full client-side re-sort on every write anywhere in the matched set (`C1`); "mark requests as seen" does a full-collection scan with no supplier/org scoping (`C2`). One more Critical: the 500-project dashboard renders all cards eagerly with per-card provider instantiation, no lazy building (`C3`). Several High items also unfixed: no server-side KPI aggregation (full history downloaded per dashboard visit), zero use of Riverpod `.select()` causing full-screen rebuild cascades, per-project procurement summary re-scanning the entire request/quote list per project.

**Required actions:** All three Critical items need design work before scale (10k RFQs / 500 projects / 100 suppliers), not a same-session patch — flagged as the top follow-up priority in the source report's own recommended order.

---

## Scalability — 62/100

**Strengths:** Storage/rules layer scales fine (deny-by-default, no per-user upload surface to bound). Batch-write patterns already respect the 500-write Firestore limit. Catalog search's manual pagination uses real document cursors, not offset-based paging.

**Remaining gaps:** The three Critical performance items above (C1–C3) are fundamentally scalability findings — the app was evaluated explicitly against a target scale (100 users / 500 projects / 10k RFQs / 100 suppliers) and multiple read/render paths grow with platform-wide data rather than per-tenant data. Single shared Firebase project means no environment-level scaling isolation either.

**Required actions:** Same as Performance C1–C3 — supplier inbox query redesign (denormalized per-supplier inbox), server-side KPI aggregates, dashboard lazy rendering. These are the single largest lever on both cost and scalability at the stated target.

---

## Reliability — 68/100

**Strengths:** Connectivity handling is event-based (no polling); cache-first dashboard rendering never blocks the UI on network. Idempotent RFQ submission via `clientOperationId` prevents duplicate-RFQ risk on retry (confirmed fixed since 2026-07-24). No memory leaks found in spot-checked controllers/listeners/subscriptions.

**Remaining gaps:** No backups at all (PITR, export) — the single biggest reliability gap, compounded by the RFQ-delete orphan issue. Offline RFQ submit can hang indefinitely with no timeout/cancel (`H2`). 5 of 6 dashboard streams have no bootstrap timeout/fallback, unlike the one that does — can't distinguish "loading" from "stalled" from "empty" (`M11`). No incident-response runbook exists anywhere (`H10`). No rollback story for a bad native release or corrupted Firestore data beyond web hosting/rules (`M7`).

**Required actions (owner):** PITR + scheduled export (blocking). **Required actions (code):** add offline-submit timeout/cancel, extend bootstrap-timeout pattern to remaining dashboard streams, write an incident-response runbook (docs, not code).

---

## UX — 58/100

**Strengths:** Per `FIRST_IMPRESSION_AUDIT.md`, most of the product is genuinely close to release-ready — RTL correctness is solid throughout (alignment, icon mirroring, form layout); requests/quotes/profile screens are clean and well-organized with clear status pipelines; empty states are thoughtfully handled via a shared widget; mobile is a real adaptive design (sidebar→bottom-tab), not a squeezed desktop layout; typography/color consistent app-wide.

**Remaining gaps:** Two **Critical, ship-blocking** UX defects — the primary "New Request" dashboard CTA (the single most important action in the app) crashes to a dead-end, unrecoverable black error screen, and the Catalog nav item does the same, reproduced consistently across sessions and widths. A first-time user hits one of these within their first minute. Major issues: large unbalanced empty space on desktop detail pages, an unstyled "Compare offers" link that looks non-interactive, a password-field placeholder that misleadingly looks pre-filled, demo-mode banner sharing the app's warning color. Minor: unrealistic demo prices, dense unlabeled info sections. Onboarding also lands new users on stub tabs marked "coming soon" with no guidance (`H1`).

**Required actions:** Fix the two crash-to-dead-end defects — treat as ship-blockers independent of root cause, and make the error boundary itself non-fatal everywhere. This is the single highest-leverage fix in the entire scorecard: it blocks the literal core action of the product.

---

## Accessibility — 20/100

**Strengths:** RTL/Hebrew localization itself is excellent and is a real accessibility win for the target market (correct mirroring, alignment, reading order).

**Remaining gaps:** Zero `Semantics(` usage anywhere in the app; no screen-reader labels on icon buttons or custom widgets (`M1`, confirmed repo-wide). No accessibility testing was in scope for any of the seven source reviews beyond this one negative confirmation.

**Required actions:** Not a closed-beta blocker per `NO_GO_CHECKLIST.md` (explicitly called out as "real gap, not specific to closed beta with a small cohort"), but should be scoped as real engineering work before any wider or public rollout — this is a genuine gap, not a config/console item.

---

## Testing — 74/100

**Strengths:** Per memory (`testing-quality-review-2026-07-24`), +93 tests landed in a prior pass (parsing/VAT/delivery/approval/dialogs). This cycle: 79 Firestore rules tests re-verified green on the emulator after security fixes; 3 emulator suites (supplier-quote-eligibility, security-review, tender-bid) all green, confirmed this session with Java 21 available. Performance fixes were verified against `flutter analyze` (clean) and the relevant existing suites, all green.

**Remaining gaps:** No `fake_cloud_firestore`/mockito-based repository-level tests for the transactional `acceptInvitation` rewrite or idempotent `submitQuoteRequest` doc-id — deliberately deferred, test infra doesn't exist on this branch (per `docs/PRE_BETA_OPERATIONS.md`, exists on a sibling branch). Per earlier memory, tests run rules-less in some contexts and one flaky parallel-run / machine-coupled dry-run test was previously flagged. `M5` fallback path in supplier-directory service isn't exercised by any test examined.

**Required actions:** Port or rebuild the missing repository-level test infra for the invitation/RFQ-submit transactional paths before those code paths change again without a safety net.

---

## Documentation — 70/100

**Strengths:** Unusually thorough for this stage — 7 dedicated audit/checklist documents alone, plus `docs/PRE_BETA_OPERATIONS.md`, `docs/CRASH_REPORTING_SETUP.md`, `docs/ANALYTICS_SETUP.md`, `docs/ANALYTICS_RELEASE.md`, catalog/architecture docs. Legal docs and support docs are honestly labeled as beta-draft where true rather than presented as final.

**Remaining gaps:** `docs/legal/PRIVACY_POLICY.md` / `TERMS_OF_SERVICE.md` still contain literal placeholders (`[COMPANY LEGAL NAME]`, `[YYYY-MM-DD]`, `[age]`) despite in-app copy being config-driven — drift risk (`M2`). No end-user help/FAQ exists anywhere — every doc is developer/operator-facing (`L2`, acceptable for hands-on closed beta only). No incident-response runbook (`H10`).

**Required actions:** Sync legal doc placeholders with shipped config values or mark clearly as inactive templates. Write an incident-response runbook before broader rollout.

---

## Operations — 45/100

**Strengths:** Every operational gap is precisely scoped and none require large engineering lifts — `RELEASE_OPERATIONS_REPORT.md` maps 21 discrete ops items with clear owner-vs-code ownership. Secrets hygiene is genuinely good (`.gitignore` correctly excludes all real credential files; no real secrets found in git history).

**Remaining gaps:** Two hard blockers: `google-services.json` and `GoogleService-Info.plist` are both absent, breaking native Crashlytics/Analytics regardless of code correctness. Single shared Firebase project for dev/QA/prod with no infrastructure isolation. No `platformAdmin` claim confirmed provisioned against the live project. Firestore indexes not confirmed deployed/built live. No scheduled export or PITR. `AppConfig` production dart-defines (support email, company name, version) have no enforcing build pipeline — a default build silently ships as `dev` with verbose diagnostics on.

**Required actions (all owner/console, cannot be completed in code):** see the dedicated section below.

---

## Monitoring — 30/100

**Strengths:** Crashlytics and Analytics are both correctly wired in code end-to-end, gated behind feature flags, with a documented 16-event closed-beta funnel.

**Remaining gaps:** Both `FEATURE_ANALYTICS` and `FEATURE_CRASH_REPORTING` default to `false` with no build script/CI job/flavor that turns them on — a default build ships fully blind (Critical, `C1`). No native config files means even a correctly-flagged build can't actually report (Critical, `C2`) — and failure is caught silently, falling back to a no-op reporter with zero signal that it isn't working. No monitoring beyond Crashlytics/Analytics — no `firebase_performance`, no Cloud Monitoring alerts, no uptime checks, no paging (`M8`). `catalogRfqAnalyticsProvider` item-level events remain hardcoded no-op in release, a deliberately-scoped-out gap (`H5`).

**Required actions (owner):** Turn on both flags in the actual beta build command, install native config files, enable Crashlytics/Analytics in console, confirm one test event/crash lands before day 1.

---

## Analytics — 40/100

**Strengths:** Same wiring quality as Monitoring — `firebase_analytics` correctly integrated behind a flag, 16-event funnel documented, `AdminRepository`-style aggregation exists as a reusable pattern for future KPI work.

**Remaining gaps:** Same root blocker as Monitoring (flag defaults off, no config files) — zero real usage data until both are resolved. Item-level catalog/RFQ interaction events (`catalog_selector_opened`, `manual_item_added`, etc.) are out of scope for this release, a real chunk of product-usage signal that stays dark even after the main funnel is fixed.

**Required actions:** Same as Monitoring; additionally decide whether item-level catalog analytics is in scope for closed beta or explicitly deferred.

---

## Crash Reporting — 35/100

**Strengths:** Code wiring is real and complete — `crashlytics_crash_reporter.dart` calls `FirebaseCrashlytics.instance`, gated correctly, with graceful (if silent) fallback behavior.

**Remaining gaps:** Cannot function at all without native config files (Critical blocker, shared with Monitoring/Operations). Not enabled in the Firebase console per this session's review. Not device-verified. Several `auth_service.dart` catch blocks only `debugPrint` (invisible in release) rather than reporting to Crashlytics even once wiring is live (`M3`). Web builds have no crash coverage by design — documented honestly, not a bug (`M4`).

**Required actions (owner):** Install native config files, enable console, do one physical-device test crash and confirm it lands. **Required action (code, minor):** route the silently-swallowed auth-path errors to the crash reporter.

---

## Maintainability — 73/100

**Strengths:** Consistent architectural patterns across repositories/services/providers. Good precedent-setting fixes this cycle (parallelized N+1 reads, WriteBatch conversions) that generalize cleanly to the remaining flagged instances. Lint config exists and is mostly enforced.

**Remaining gaps:** `analysis_options.yaml` ignores `use_build_context_synchronously` and `deprecated_member_use`, reducing CI signal quality (`M11`, per memory also noted as a prior "quirk"). Duplicate/dead code identified (unwired catalog repository with a latent pagination-cursor bug, duplicate `blockUser`/`disableUser` paths). No runtime kill-switch — feature flags are build-time only, so a bad flag requires a full rebuild (`M6`).

**Required actions:** Remove or re-enable the ignored lint rules with a scoped cleanup pass. Delete confirmed-dead code paths rather than let them drift further out of sync.

---

## Developer Experience — 78/100

**Strengths:** Strong internal documentation density (architecture docs, per-feature setup guides, checklists). CI runs analyze/test/web-build. Firestore emulator suite is fast and green, usable for local iteration without live project access. Clear separation of concerns makes it straightforward to locate the right layer for a change.

**Remaining gaps:** No signed Android/iOS release job in CI — only web build is automated end-to-end (`H6`). Conflicting Gradle DSL files (dead `.gradle.kts` alongside active Groovy) with disagreeing application IDs, a real source of local-setup confusion (`H7`).

**Required actions:** Delete the dead Gradle Kotlin DSL files and reconcile application IDs across Android/iOS — small, mechanical, and currently a genuine trap for anyone building natively.

---

## Deployment — 38/100

**Strengths:** Web hosting deploy pipeline is real, exercised, and verified (`firebase.json` hosting config valid, SPA rewrite correct, a prior `build/web/` output present). Rollback exists for web hosting and Firestore rules via git tags.

**Remaining gaps:** Android release build is signed with the **debug keystore** — store submission impossible in this state (`C5`). No build flavors (dev/staging/prod) for any platform (`H6`). Native config files absent block any native build's Firebase init (`H8`). Version still at template default `1.0.0+1`, no CHANGELOG, no store-ready icon/splash, R8/minify not enabled (`M5`). No rollback story for a bad native release or corrupted Firestore data (`M7`).

**Required actions:** Explicitly out of scope for closed beta per `GO_CHECKLIST.md`'s separate store-release gate — real keystore, build flavors, CI signing job, Gradle/app-ID reconciliation, store assets. Sideload/TestFlight-style distribution is sufficient for closed beta as-is.

---

## Support — 55/100

**Strengths:** Support contact action is correctly wired end-to-end (analytics-tracked, tested) with an honest fallback (clipboard-copy) rather than a fabricated address when unconfigured — confirmed fixed since the 2026-07-24 review.

**Remaining gaps:** `AppConfig.supportEmail` defaults to empty — without a real `--dart-define` at build time, beta users get a copy-link fallback instead of a working channel (`H3`). No impersonation/"sign in as user" capability exists anywhere — a stuck user can only be helped via screen-share or an engineer opening the Firestore/Auth console directly (Critical, `C9`). No in-app data-repair tooling for admins — any correction requires direct console access (`M9`).

**Required actions (owner):** Set a real `SUPPORT_EMAIL` for the beta build. Agree on and document a manual "act as admin support" process for the beta window given no impersonation exists (this is an ops/process decision, not a near-term code fix).

---

## Overall Production Readiness — 58/100

This is a **weighted synthesis, not an average** — Security/Firestore/Reliability/Operations/Monitoring carry more weight than Deployment/Accessibility because the former directly gate "can a real company's data safely live here," which is the explicit bar every source document (especially `NO_GO_CHECKLIST.md`) applies.

### Classification: **Closed Beta — NOT YET (Internal Testing today; Closed Beta Ready once the GO_CHECKLIST boxes are checked)**

This matches `NO_GO_CHECKLIST.md`'s own verdict: **NO-GO today**, for reasons that are real but narrow — no backups, hardcoded weak credentials in the release binary, blind monitoring, no impersonation/support tooling, and (from `FIRST_IMPRESSION_AUDIT.md`) the single most important button in the app currently crashes to a dead end. None of these are large engineering lifts; most are config/console/ops actions already fully scoped in `docs/PRE_BETA_OPERATIONS.md` and `GO_CHECKLIST.md`. Once those specific items are closed, this product moves to **Closed Beta Ready** — it is explicitly **not** ready for public/app-store release regardless (separate, larger gate: signing, build flavors, store assets).

---

## Remaining Owner Actions (cannot be completed in code — console, ops, or human-process only)

1. **Enable Firestore PITR** on the production project (`gcloud`/console setting).
2. **Set up a scheduled Firestore export** (Cloud Scheduler → Cloud Function, or cron `gcloud firestore export`) to a GCS bucket.
3. **Download and install `android/app/google-services.json`** from the Firebase Console.
4. **Download and install `ios/Runner/GoogleService-Info.plist`** (and macOS equivalent if shipped) from the Firebase Console.
5. **Enable Crashlytics in the Firebase Console** and do a real physical-device test crash to confirm it reports.
6. **Enable Analytics in the Firebase Console** and confirm at least one event lands in DebugView.
7. **Run `tools/admin/set_platform_admin.js`** against the live project for the intended admin account(s); confirm via sign-out/sign-in that the `platformAdmin` claim takes effect.
8. **Run `firebase deploy --only firestore:indexes`** and confirm all 22 (+2 new `auditEvents`) indexes show "Enabled" in the console.
9. **Confirm Email/Password sign-in provider is toggled on** in Firebase Console → Authentication, and that no unused providers (e.g. anonymous auth) are accidentally enabled.
10. **Configure Firebase Auth built-in email templates** (password reset, verification) with real sender name/branding in the console.
11. **Decide and pass real production `--dart-define` values** for the beta build: `SUPPORT_EMAIL`, `COMPANY_LEGAL_NAME`, `APP_ENV=prod`, `FEATURE_ANALYTICS=true`, `FEATURE_CRASH_REPORTING=true` — and establish this as an actual build script/CI job rather than a manually-remembered flag set.
12. **Rotate/remove the hardcoded QA/admin passwords** (`123123`, `Qa123456!`) from live use and require forced password reset for any account provisioned through `tools/admin/admin_onboarding.js` — a credential-rotation action with real account implications, not a safe blind code change.
13. **Decide whether to separate the Firebase project** used for QA/demo/seed data from the one real customer data will live in, or explicitly accept the single-project risk in writing for this beta cycle.
14. **Get explicit legal sign-off** that the current beta-draft Privacy Policy/Terms framing is acceptable for a closed, invite-only cohort.
15. **Agree on and document a manual "admin support" process** for the beta window (screen-share or engineer console lookup) since no in-app impersonation exists.
16. **Agree on a manual single-admin-at-a-time process** for access-request approvals during the beta window, given the known un-fixed double-approval race.
17. **Bump `pubspec.yaml` version** off the template default `1.0.0+1` for the beta release.
18. **Sign off in writing** on the full `GO_CHECKLIST.md`, or explicitly waive specific items with the risk accepted by the product owner.
