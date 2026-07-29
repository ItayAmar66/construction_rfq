# GO Checklist — Closed Beta

Scope assumption: a **small, trusted, hands-on closed beta** (a handful of real companies, engineering team reachable directly) — not a public app-store launch. Store-release items (signing, flavors, CI release job) are called out separately at the bottom since they gate a *later* wider rollout, not this closed beta.

Check every box below before inviting a real company's data into this system. All items reference `CLOSED_BETA_CHECKLIST.md` for detail.

## Data safety (do these first — irreversible if skipped)
- [ ] **Rotate/remove hardcoded weak passwords** (`123123`, `Qa123456!`) from `admin_management_panel.dart` and `tools/admin/admin_onboarding.js`; require forced password reset for any account created through the onboarding script. (C3, C8)
- [ ] **Separate the Firebase project** used for QA/demo data from the one real customer data will live in — or, at minimum, stop running QA smoke tests / seed scripts against the project real customers will use. (C4)
- [ ] **Enable Firestore PITR and a scheduled export** on the production project. (C6)
- [ ] **Close or mitigate the RFQ-delete orphan gap** — either add a rule/service check blocking delete while child `supplierQuotes` exist, or accept the risk explicitly in writing since there's no backup to fall back on until the item above is done. (C7)

## Observability (do before the first real user, not after)
- [ ] **Turn on `FEATURE_ANALYTICS` and `FEATURE_CRASH_REPORTING`** in the actual beta build command (`--dart-define=...=true`) — confirm this is in the real build script/CI job, not just known in a doc. (C1)
- [ ] **Add `google-services.json` / `GoogleService-Info.plist`** and enable Crashlytics in the Firebase console; do one test throw on a real device/build to confirm an event lands in the console. (C2, H8)
- [ ] Confirm at least one analytics event and one crash test-event are visible in the Firebase console before day 1. (C1, C2)

## Support & self-service for the beta cohort
- [ ] **Set a real `SUPPORT_EMAIL`** via `--dart-define` in the beta build so the in-app support action reaches a monitored inbox instead of the clipboard fallback. (H3)
- [ ] **Confirm at least one person can act as admin support** — since there's no impersonation, agree on a manual process (e.g., screen-share, or engineer console lookup) for the beta window. (C9)
- [ ] Communicate the reachable stub tabs ("coming soon" tabs) to beta users up front, or hide them, so they don't read as broken. (H1)

## Legal
- [ ] Confirm the in-app Privacy Policy / Terms are acceptable for a *closed, invite-only* beta (they already say "beta draft, pending legal review" — get explicit sign-off from whoever owns legal risk that this framing is enough for this cohort). (H4)
- [ ] Sync `docs/legal/PRIVACY_POLICY.md` / `TERMS_OF_SERVICE.md` placeholders with the shipped config values, or mark them clearly as templates not in effect. (M2)

## Admin operational readiness
- [ ] Confirm the one documented admin-bootstrap path (`docs/ADMIN_BOOTSTRAP.md`) has been run against the real project and a real human holds the `platformAdmin` claim. (resolved — verify it was actually run for the target project)
- [ ] Agree on a manual process for the two known approval-flow races (H12, H13) during the beta window — e.g. "only one admin approves access requests at a time" — until fixed in code.

## Sign-off
- [ ] All boxes above checked, or explicitly waived in writing by the product owner with the risk accepted.
- [ ] `CLOSED_BETA_CHECKLIST.md` Critical section fully resolved or waived.

---

## Separate gate: public/app-store release (not required for closed beta, required before wider rollout)
- [ ] Real Android signing keystore (not debug) configured in CI. (C5)
- [ ] Build flavors (dev/staging/prod) + a CI job that produces a signed release artifact. (H6)
- [ ] Reconcile conflicting Gradle DSL files and mismatched application IDs across Android/iOS. (H7)
- [ ] Store-ready icon/splash assets, version bump off `1.0.0+1`, R8/minify enabled. (M5)
