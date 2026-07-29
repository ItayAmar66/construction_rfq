# Final Release Review Board — construction_rfq

**Branch:** `feature/full-project-centric-redesign` · **Review date:** 2026-07-28
**Scope:** Reconciliation of all 39+ prior audits/checklists/reports plus current git/working-tree state. This board verifies every prior finding carries one of **Fixed / Accepted / Owner Action**; it does not repeat prior analysis or introduce new findings except where reports conflict or a finding fell through the cracks between documents.

---

## ⚠️ Most Important Finding: Key Fixes Are Uncommitted

The working tree currently shows:

```
 M firestore.rules
 M lib/services/auth_service.dart
```

- `firestore.rules` (+76/-? lines): implements the Red Team fixes — RFQ-resubmit forgery guard, legacy-collection tenant scoping, invitation-expiry cap. `RED_TEAM_REPORT.md` marks these "✅ fixed," but that's only true of the working tree, not of any commit.
- `lib/services/auth_service.dart` (+161/-57 lines): fixes a real session bug — a permission-denied event on the `users/{uid}` profile stream (e.g. disabled account, revoked org membership) was previously swallowed, leaving a stale authenticated `AuthSession` alive indefinitely. The uncommitted change treats permission-denied as terminal and emits `AuthSession.empty`, closing the dead subscription. This is a genuine reliability/security fix not documented in any prior report.

**If this tree is reset, or a clean checkout is what gets built and deployed for beta, all of these fixes disappear and the app reverts to the vulnerable/buggy state the reports describe as fixed.** Committing and deploying both files is the single highest-priority action, ahead of any other item below.

---

## Overall Readiness

| Track | Verdict |
|---|---|
| **Closed Beta** (small, trusted, hands-on cohort) | **CONDITIONAL GO** — once the blockers in the next section are closed or explicitly waived in writing by the product owner |
| **Production / public release** | **NO-GO** — a separate, larger gate (store signing, environment isolation, scalability redesign, accessibility completion, full QA coverage) |

This is consistent with every document that issued an explicit verdict: `NO_GO_CHECKLIST.md` ("NO-GO today"), `PRODUCTION_READINESS_SCORECARD.md` (58/100, "Closed Beta: NOT YET"), `RELEASE_DRY_RUN.md` ("Overall verdict: NO-GO"), and `GO_CHECKLIST.md` (no boxes checked). None of these documents have been updated to reflect a later "all clear" — this board's CONDITIONAL GO for closed beta reflects that the remaining gap is narrow (mostly owner/console actions plus committing already-written code), not that the gap is closed.

---

## Remaining Blockers (Closed Beta)

Must be fixed or explicitly waived in writing by the product owner before a real company touches this:

| # | Blocker | Type | Why it blocks |
|---|---|---|---|
| B0 | `firestore.rules` and `auth_service.dart` fixes are uncommitted | Code (trivial — commit + deploy) | See above; everything else in this report that cites these fixes as "done" is contingent on this |
| B1 | RFQ delete has no check for child `supplierQuotes` → permanent orphaned data | Code | Combined with B2, the only irreversible data-loss path triggerable by routine user action |
| B2 | No Firestore PITR / scheduled export configured | Owner (console) | Zero recovery path for B1 or any other data-loss bug |
| B3 | Hardcoded weak passwords (`123123`, `Qa123456!`) shipped in release binary / onboarding script, no forced reset | Owner + code | Live credential exposure once the binary reaches an outside device |
| B4 | Single shared Firebase project for dev/QA/prod | Owner (console) | No blast-radius isolation between internal testing and real beta-company data |
| B5 | `google-services.json` / `GoogleService-Info.plist` missing | Owner (console download) | Native Firebase init (Crashlytics/Analytics/Auth on mobile) is broken without these |
| B6 | `approveAccessRequest`/`rejectAccessRequest` not re-checked for `pending` status inside the write (double-approval race); same non-atomicity shape in the last-owner-demotion guard | Code (deferred, larger transactional change) | Low-likelihood at small-cohort scale; acceptable to **waive explicitly** for closed beta if logged as an accepted risk with a manual "one admin approves at a time" process — not acceptable to leave un-acknowledged |

Everything else surfaced across all reports (analytics/crash-reporting activation, build signing, store assets, environment separation beyond B4, accessibility completion, scalability redesign, full manual QA coverage, legal finalization, notification wiring) is real but does not block a small hands-on closed beta. Tracked below.

---

## Remaining Owner Actions (non-blocking for closed beta, required before wider rollout)

**Console/credential actions (no code involved):**
- Enable Crashlytics and Analytics in Firebase console; confirm the beta build pipeline actually sets `FEATURE_ANALYTICS`/`FEATURE_CRASH_REPORTING` to `true` — today's default build silently ships as `dev` with both off, so beta would otherwise fly blind
- Confirm `platformAdmin` bootstrap script has been run against the live project and the custom claim landed
- Confirm Firestore indexes are deployed and built (`firebase deploy --only firestore:indexes`), not just committed in code
- Confirm Email/Password auth provider is enabled in console; brand the password-reset/verification email templates
- Set real `SUPPORT_EMAIL` and `COMPANY_LEGAL_NAME` dart-defines; reconcile `LICENSE` placeholder and `docs/legal/*.md` placeholders
- Agree and document a manual "impersonate a user for support" process (no in-app tooling exists)
- Configure TTL policy on `invitations`/`accessRequests`/`auditEvents` (cost hygiene, not correctness)
- Bump `pubspec.yaml` off `1.0.0+1`

**Product decisions required (not resolvable as pure code or pure ops):**
- Invitation delivery: ship copy-link-only for beta, or build the `sendInvitationEmail` Cloud Function first
- Org enumeration / PII (phone, email, address) leak to unapproved-but-pending accounts via the `organizations` list rule — flagged once by Red Team, never picked up by any later checklist; needs an explicit scoping decision
- **Contradiction requiring direct verification, not assumption:** `CODEX_AUDIT_2_TECHNICAL_FIREBASE.md` claims users can write their own `userType` on `/users/{uid}` (privilege-escalation risk); `SECURITY_NOTES.md` claims `userType` is immutable on update. No later report reconciles this. Read the current `firestore.rules` update rule for `/users/{uid}` directly before shipping.

**Store/production-only (do not block closed beta):**
- Android release signing (currently debug keystore), iOS distribution signing + `exportOptions.plist`
- Resolve conflicting Gradle DSL files / 3 disagreeing application IDs
- Build flavors (dev/staging/prod) + signed release CI job
- Store icons/splash/assets
- R8/minify enablement, runtime kill-switch via Remote Config

---

## Explicitly Accepted Risks (documented, not oversights — no action needed unless the board or owner revisits)

- Client-enforced project-deletion grace period — no real payoff yet since no purge job exists
- No router-level `/admin/**` guard — informational only, every admin screen self-guards server-side
- `PlatformAdmin.bootstrapEmails` client-side trap — cosmetic only today
- Legacy dead code (`blockUser()` vs `disableUser()`, unwired catalog repo cursor bug) — cleanup, not urgent
- Item-level catalog/RFQ analytics events remain no-op — explicitly out of scope per `docs/ANALYTICS_RELEASE.md`
- Web has no crash coverage — documented honestly as a Flutter-web SDK limitation, not a bug
- Firestore rules don't validate RFQ/quote schema, prices, or status transitions server-side — documented limitation, app-layer validation only, Cloud Functions path documented but not built
- No external search engine (Algolia/Typesense) for catalog — explicit Phase 1 decision, Firestore-native only
- Supplier targeting broad-visibility default, no hard cutover — deliberate soft-launch phase
- RTL symmetric-EdgeInsets/hardcoded-alignment findings — low-priority, deferred
- Legacy `/cart` routes retained alongside RFQ language — deliberate backward compatibility

---

## Risk Assessment by Category

| Category | Level | Note |
|---|---|---|
| Security | High → Medium once B0 committed | 4 real vulns fixed but sitting uncommitted (B0); userType-mutability conflict needs direct verification; hardcoded creds (B3) still live |
| Firestore / data durability | **Critical** | No backups (B2) + unguarded RFQ delete (B1) = real chance of unrecoverable data loss from routine action |
| Permissions | Medium | Core model feature-complete and server-enforced; B6 races real but low-likelihood at beta cohort size, mitigated only by an unenforced manual process |
| Performance | Medium | Straightforward wins landed (batching, debounce, caching, N+1 fixes); expensive fixes are correctly deferred, not silently dropped |
| Scalability | Medium-High (time-bombed) | Quantified ~$23.6K/mo cost cliff at 10K companies from unbounded marketplace listeners; irrelevant at beta scale, must gate any wider rollout |
| Reliability | Medium | Major lost-update/double-submit races closed and verified (`ad5cb35`) plus the uncommitted auth-session fix; two known races remain, explicitly documented, not hidden |
| Accessibility | Low for closed beta / Medium for wider rollout | Comprehensive pass from a true zero baseline (`799c38d`); still incomplete (dialog focus, card semantic labels) |
| UX | Low | The one true ship-blocking crash (dead-end error screen on primary CTA) fixed in `d889131`, verified by code trace — recommend one live browser click-through before beta opens since it wasn't independently re-verified live |
| Manual QA | Medium-High (coverage gap) | `MANUAL_QA_REPORT.md` itself says "IN PROGRESS" — Supplier flows, Admin flows, and the full permissions matrix have not been walked end-to-end; treat any "QA passed" claim elsewhere with caution |
| Operations | High until owner actions close | Two hard blockers (B4, B5) plus a list of console-only actions; none require code |
| Release (build/signing) | Blocking for stores, non-issue for closed/sideloaded beta | Explicitly a separate, later gate |
| Analytics | Currently blind | Code complete and correct (`3466dec`); collects nothing until owner actions above are done |
| Crash Reporting | Currently blind | Same shape as Analytics (`4e3d0e2`); also silently falls back to a no-op reporter on native init failure with zero alerting — worth a log-based check post-launch |

---

## Final Recommendation

### Closed Beta: **CONDITIONAL GO**

Proceed once these are each fixed or explicitly waived in writing by the product owner with the risk accepted:
1. Commit and deploy `firestore.rules` + `auth_service.dart` (B0) — today's single most urgent action
2. Add the RFQ-delete orphan check (B1)
3. Enable Firestore PITR/backups (B2)
4. Rotate/remove hardcoded demo credentials, force reset (B3)
5. Decide on Firebase project separation or accept shared-project risk in writing (B4)
6. Install native config files and confirm Crashlytics/Analytics actually receive an event, not just wired (B5)
7. Waive or fix the access-request approval race, logged explicitly (B6)

None of these require architectural rework. B1 and the B6 transactional fix are the only ones needing new code; B0 needs only a commit and deploy of code that already exists.

### Production / Public Release: **NO-GO**

Do not schedule until: the marketplace-listener scalability redesign lands, accessibility work continues past the current pass, manual QA coverage is completed across Supplier/Admin/full permissions matrix, and the full store-release checklist (signing, flavors, environment isolation, legal finalization) is closed.

---

*This board does not modify any code. No findings were newly introduced beyond what the prior reports and current working-tree state establish, except B0 (uncommitted-fix detection) and the two cross-report contradictions/gaps flagged above, which are reconciliation findings, not new audits.*

*Reconciled from: PRODUCTION_READINESS_SCORECARD.md, CLOSED_BETA_CHECKLIST.md, GO_CHECKLIST.md, NO_GO_CHECKLIST.md, MANUAL_QA_REPORT.md, RED_TEAM_REPORT.md, RELIABILITY_REPORT.md, CODEX_AUDIT_1_PRODUCT_QA.md, CODEX_AUDIT_2_TECHNICAL_FIREBASE.md, ACCESSIBILITY_REPORT.md, FIRST_IMPRESSION_AUDIT.md, SCALABILITY_AND_COST_REPORT.md, SCALABILITY_FIX_REPORT.md, PERFORMANCE_REPORT.md, SECURITY_NOTES.md, RELEASE_CHECKLIST.md, RELEASE_OPERATIONS_REPORT.md, RELEASE_DRY_RUN.md, UX_POLISH_COMPLETION.md, TOMORROW_SMOKE_TEST.md, COMPANY_DEMO_QA_CHECKLIST.md, REAL_DEVICE_QA_SCRIPT.md, FIREBASE_PRODUCTION_CHECKLIST.md, NOTIFICATIONS_FOUNDATION.md, ROLES_AND_PERMISSIONS.md, all CATALOG_*.md reports, and current git/working-tree state as of 2026-07-28.*
