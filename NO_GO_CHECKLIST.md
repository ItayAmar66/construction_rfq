# NO-GO Checklist — Current Blockers (as of 2026-07-27)

**Verdict as of this review: NO-GO today.** The product's core RFQ→quote→order→delivery loop works and several 2026-07-24 blockers are genuinely fixed (see `CLOSED_BETA_CHECKLIST.md`), but the items below are still true right now and each represents a real company's data or trust being put at risk with no safety net.

This is the inverse of `GO_CHECKLIST.md` — every item here is a reason to hold, not a task list. Once an item's underlying `GO_CHECKLIST.md` box is checked, cross it off here too.

## Why this is a NO-GO right now

- **A shared Firebase project means real customer data and QA/test data live in the same place**, with hardcoded weak passwords (`123123`, `Qa123456!`) baked into the release binary and the admin onboarding script that provisions real accounts. Anyone who finds these credentials — or any QA script run against the wrong project — has a direct path to real customer data. *(C3, C4, C8)*

- **There are no backups.** No PITR, no scheduled export, nothing. If anything goes wrong — a bad script, an admin mistake, a bug in a non-atomic write path already known to exist (see `docs/KNOWN_LIMITATIONS.md`) — there is no way back. Combined with the fact that RFQ deletion already orphans child quote documents by design, a single ordinary user action (deleting an RFQ that has quotes) creates permanent, un-fixable data loss today. *(C6, C7)*

- **The app ships blind.** Analytics and crash reporting are correctly wired in code, but both feature flags default off and no build script turns them on, and the native Firebase config files Crashlytics needs to actually report aren't in the repo. Launching today means finding out about problems only when a beta user complains, not when they happen. *(C1, C2)*

- **There is no way to help a stuck user without an engineer.** No impersonation, no "view as," no in-app data-repair tooling — a beta user having a bad day means either an engineer opens the Firestore console, or they stay stuck. For a "self-serviceable enough for real companies" bar, this fails. *(C9, M9)*

- **Store distribution is not possible in this state** — Android release builds are debug-signed, there's no CI job that produces a real release artifact, and application IDs disagree across platforms. This doesn't block a small sideloaded/TestFlight-style closed beta, but it means "closed beta" cannot casually turn into "wider rollout" without separate work. *(C5, H6, H7, H8)*

## What would need to change for this to flip to GO

See `GO_CHECKLIST.md` — every item there maps directly to one of the bullets above. None of them are large engineering lifts (most are config/console/ops actions, already scoped in `docs/PRE_BETA_OPERATIONS.md`); the blocker is that they haven't been done yet, not that they're hard.

## What is genuinely NOT a blocker (don't over-rotate on these)

- Placeholder/legal-draft language in the in-app Privacy Policy/Terms — acceptable framing for an invite-only closed beta with a small trusted cohort, *if* explicitly signed off (see `GO_CHECKLIST.md` legal section). Not a NO-GO by itself.
- Reachable "coming soon" stub tabs — cosmetic, manageable by briefing beta users, not a data-safety or trust issue.
- Missing accessibility (Semantics) support — real gap, not specific to *closed beta with a small cohort*; doesn't block this launch stage.
- Lack of build flavors / CI signing / store assets — blocks a *public* release, not a closed, sideloaded/internal beta.
