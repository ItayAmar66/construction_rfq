# Pre-Beta Operations Checklist

Status as of this pass (branch `feature/full-project-centric-redesign`).
Categorized honestly: what's done in code, what's externally verified
(nothing in this list — no console/device access in this environment), and
what still requires the project owner to act.

| Item | Status | Notes |
|---|---|---|
| `platformAdmin` custom claim provisioned and tested | **Still requires owner action** | `lib/services/platform_admin.dart`'s `bootstrapEmails` remains a client-only UI gate (comment says so explicitly); no server-side custom-claim provisioning happened in this pass — out of scope (backend/console work, not a code fix). |
| Firestore PITR enabled | **Still requires owner action** | Console setting, not verifiable or settable from code. No backup exists today per prior review — RFQ-delete still orphans child quotes without it. |
| Scheduled export enabled | **Still requires owner action** | Same as above — console/Cloud Scheduler configuration. |
| Crashlytics enabled in Firebase console | **Completed in code, requires owner action to activate** | `lib/services/crashlytics_crash_reporter.dart` wires it end-to-end behind `FEATURE_CRASH_REPORTING`; owner must enable Crashlytics in the console, add `google-services.json`/`GoogleService-Info.plist` (not in this repo), and ship with the flag on. See `docs/CRASH_REPORTING_SETUP.md`. Not device-verified in this session. |
| Analytics enabled | **Completed in code, requires owner action to activate** | `lib/analytics/app_analytics.dart` wires Firebase Analytics behind `FEATURE_ANALYTICS`, instrumenting the 16-event closed-beta funnel. Owner must enable Analytics in console and ship with the flag on. See `docs/ANALYTICS_SETUP.md`. Not DebugView-verified in this session. |
| Committed QA credentials rotated | **Still requires owner action** | Weak passwords (`123123`, `Qa123456!`) remain in `docs/qa/*`, `RELEASE_CHECKLIST.md`, `lib/screens/admin/admin_management_panel.dart` per the prior review — not touched this pass (out of scope: rotating live credentials is an ops action, not a code diff this session can safely make blind). |
| Production support email configured | **Completed in code (fallback), requires owner action for a real inbox** | `lib/utils/support_contact.dart` + `AppConfig.supportEmail` are wired; default is empty (clipboard-copy fallback) rather than a fabricated address. Owner supplies the real value via `--dart-define=SUPPORT_EMAIL=...`. See `docs/SUPPORT_CONTACT.md`. |
| Firestore emulator suite green | **Verified this session** | `test/firestore/*.emulator.test.js` — all 3 suites pass: `supplier_quote_eligibility` (6 assertions), `security_review` (55 assertions), and the new `tender_bid` suite (9 assertions covering the Phase 1 doc-id fix). Run via `firebase emulators:exec --only firestore ...`; Java 21 was available in this environment. |
| Legal placeholders removed | **Verified this session** | `[שם החברה]` / `[support@example.com]` replaced with `AppConfig`-sourced values; `test/legal_config_validation_test.dart` guards against regression. Legal *copy itself* still needs actual legal review — a beta-draft notice now says so explicitly in-app. |
| Production Firebase project confirmed | **Not independently re-verified this session** | Prior review recorded project `construction-rfq-itay-20-2eee0`, single project across all envs. Not re-confirmed here — no console access. |

## What changed this pass (for context — see individual commit messages for detail)

1. Tender counter-bid doc-id mismatch fixed + emulator-verified (`354ff4b`).
2. Invitation email-verification UX + atomic accept (`6c407c0`).
3. Real Crashlytics wiring behind the existing flag (`4e3d0e2`).
4. Real Firebase Analytics wiring behind the existing flag (`3466dec`).
5. RFQ draft persistence, offline states, submit idempotency (`8c331de`).
6. Legal placeholders + working support-contact action (`26d2fe1`).

## What this pass deliberately did NOT do

- Did not touch `firestore.rules` beyond the two additions required for the
  tender-bid fix (deterministic id + self-retire) — no broader rules
  rewrite.
- Did not rotate the committed QA passwords — flagged, not silently fixed,
  since that's an operational action with real account implications.
- Did not fabricate a company legal name or a support email domain — asked
  the user first; shipped safe defaults instead.
- Did not add `fake_cloud_firestore`/mockito-based repository-level tests
  for the transactional `acceptInvitation` rewrite or the idempotent
  `submitQuoteRequest` doc-id — no such test infra exists on this branch
  (a sibling branch has it per prior review notes); adding a new test
  dependency mid-fix was judged out of scope. Coverage instead comes from
  the emulator rules suites + notifier-level unit tests.
