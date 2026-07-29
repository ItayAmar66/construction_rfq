# Red Team Report — construction_rfq

Date: 2026-07-27
Branch: `feature/full-project-centric-redesign`
Scope: Authenticated-user attack surface of the Flutter + Firebase app — auth, authorization, Firestore rules, race conditions, cross-tenant isolation, storage, replay/idempotency, client-state hygiene.

## Architecture note (why this matters)

This is a Flutter client (mobile/web/desktop) talking **directly** to Firebase Auth, Cloud Firestore, and Cloud Storage. There is no deployed backend API or Cloud Function today. That means `firestore.rules` (and `storage.rules`) is the **entire** authorization boundary — every Dart-side permission check (`EffectivePermissions`, route guards, etc.) is UX only and trivially bypassed by any client that talks to the Firestore SDK/REST API directly with a valid ID token. Every finding below was evaluated against that reality: "does the rules file actually stop this," not "does the app's UI stop this."

All findings were verified by reading the actual rule/model/provider source (file:line evidence below), not assumed from behavior. `firebase deploy --only firestore:rules --dry-run` was used to confirm every rules change still compiles, and the existing `test/firestore_rules_security_test.dart` suite (79 tests) was run against the Firestore emulator and passes after the fixes.

---

## Findings

### 1. Cross-user RFQ draft carryover on shared session — **High**

**Where:** `lib/providers/rfq_draft_provider.dart:38-52` (`RfqDraftNotifier.attachScope`), only call site `lib/screens/customer/cart_screen.dart:70`.

**How:** `attachScope()` only restores from storage `if (state.isEmpty)`, and never reset in-memory `state` when the bound scope key changed to a different user. The Riverpod `rfqDraftProvider` is a long-lived global provider never invalidated on `AuthService.signOut()` (`lib/services/auth_service.dart:408`, plain `_firebaseAuth.signOut()`, no provider teardown).

**Repro:** User A logs in, adds items to the RFQ draft (in-memory `state` populated). A logs out. User B logs in on the same app process/tab (no full restart — realistic on Flutter Web, e.g. a shared office/kiosk browser). When the Cart screen mounts, `attachScope(uid: B)` rebinds the scope key but — because `state` is non-empty — skips restoring B's own draft and leaves A's items in place. Any edit by B persists A's items under B's storage key. If B submits, the resulting `quoteRequests` doc is created under **B's** `customerId` (identity resolved from the live auth session at submit time) but contains **A's** drafted items and A's `clientOperationId`.

**Impact:** Cross-user data leakage plus unauthorized-identity submission — content authored by A ends up submitted and attributed to B, with no server-side signal that anything is wrong (the write looks like a completely ordinary self-owned create).

**Fix applied:** `attachScope` now detects a genuine scope switch (bound uid changes) and clears in-memory `state` + rotates `clientOperationId` **before** restoring the new scope's storage, so one user's draft can never leak into another's session regardless of when/where a screen calls `attachScope`. See `lib/providers/rfq_draft_provider.dart`.

**Residual/optional hardening (not applied — needs product sign-off):** explicitly clear the outgoing user's `SharedPreferences`/`localStorage` key on logout rather than leaving it until a future draft mutation empties it, and wire `rfqDraftProvider` teardown directly into the auth-state listener instead of relying on the next Cart-screen mount.

---

### 2. RFQ resubmit smuggles forged fields through the update path — **High**

**Where:** `firestore.rules`, `quoteRequests/{requestId}` update rule, customer-owner branch (was `changedOnly(['items','notes','supplierIdsResponded', ..., 'approvedQuoteId','tenderClosed', ...])` with no further validation on the last two). Client: `lib/repositories/request_repository.dart` `submitQuoteRequest()`, which writes via `.doc(requestId).set(...)` using a client-chosen `requestId` (the idempotency key) — so a retried/duplicated submit with a different payload is evaluated as an `update`, not a `create`.

**How:** `create` requires `supplierIdsResponded.size() == 0` (`quoteRequestCreateAllowed`), but that invariant is never re-checked on `update`. The customer-owner update branch also allowed `approvedQuoteId` to be set to **any string** with no check that it references a real, linked `supplierQuotes` document (that validation, `procurementApprovedQuoteIdValidForRequest()`, existed but was only wired into the *procurement* approval branch, not the customer branch).

**Repro:** After the initial create (`supplierIdsResponded: []`), the request's own customer calls `.doc(requestId).set({...unchanged immutable fields..., 'supplierIdsResponded': ['attackerSupplierUid'], 'approvedQuoteId': '<forged id>', 'tenderClosed': true})`. The rules accepted it as a normal update.

**Impact:** A request's own customer (not even a privilege-escalation bug — this doesn't cross a tenant boundary — but a create-invariant/idempotency bypass) could forge "a supplier already responded," prematurely close a tender, or point `approvedQuoteId` at an unrelated/nonexistent quote, corrupting the order/approval flow downstream (`procurementQuoteOrderUpdateAllowed` and receipt-confirmation logic trust `approvedQuoteId` being a real, linked quote).

**Fix applied:** added `customerApprovedQuoteIdChangeValid()` (only allows `approvedQuoteId` to stay unchanged, be cleared, or be set to a value that passes the same `procurementApprovedQuoteIdValidForRequest()` linkage check used elsewhere) and `customerSupplierIdsRespondedChangeValid()` (new list must be a subset of the old one — the customer branch can only *remove* entries, never fabricate new ones; suppliers still append their own id through the separate supplier branch, unaffected). Both are now required on the customer-owner update branch in `firestore.rules`.

---

### 3. Legacy `quoteRequestItems` / `supplierQuoteItems` — unscoped cross-tenant read — **Medium**

**Where:** `firestore.rules`, `quoteRequestItems/{itemId}` and `supplierQuoteItems/{itemId}` — both had `allow read: if isSignedIn();` with **no** ownership/org/project scoping at all.

**How:** These are legacy per-line-item collections from before pricing/line items were embedded as `items[]` arrays on the parent `quoteRequests`/`supplierQuotes` docs. No live code path in `lib/` or `tools/` writes new documents into them anymore (confirmed by grep — only two read-only fallback loaders remain, `_loadLegacyRequestItems`/`_loadLegacySupplierQuoteItems`, used when a parent doc's embedded array is empty), but nothing purges pre-migration documents, and the create rules for both collections are still technically live.

**Impact:** Any authenticated user, any tenant, could `list`/`get` every document in these two collections directly via the Firestore SDK/REST API — including any pre-migration line-item/pricing data that was never cleaned up, and any doc written since if a code path is ever reintroduced. This is exactly the kind of rule that looks harmless in the current UI but is a live hole to anyone who queries Firestore directly.

**Fix applied:** both collections' `read` rules now mirror the scoping of their parent document's read rule (looked up via the existing `requestDoc()`/`supplierQuoteDoc()` helpers) — platform admin, the request's own customer, an eligible contractor-org member, or an eligible supplier, matching `quoteRequests`/`supplierQuotes` exactly. See `firestore.rules`.

**Follow-up recommended (not done here — needs a prod data audit, out of scope for a rules change):** run a one-time admin script (a template already exists in `tools/admin/manual_qa_reset.js`) to purge any surviving pre-migration documents in these two collections in production.

---

### 4. Unbounded invitation expiry — **Medium**

**Where:** `lib/repositories/invitation_repository.dart:~127` sets `expiresAt: now.add(Duration(days: 30))` client-side. `firestore.rules` `invitationCreateAllowed()` never validated `expiresAt` at all — an inviter (any org owner or `procurementManager`, who legitimately holds `canInviteOrgMembers`) could write an invitation directly via the SDK with `expiresAt` set to, e.g., 100 years out, or omit the field entirely (`invitationNotExpired()` treats a missing `expiresAt` as never-expiring).

**Impact:** A compromised or malicious inviter account could mint a permanently redeemable invite link for an arbitrary email, granting long-term persistence/escalation into the org that outlives the inviter's own access (e.g. even after the inviter is later removed). No Firestore TTL policy exists on this collection as a backstop.

**Fix applied:** `invitationCreateAllowed()` now requires `expiresAt` be present, a timestamp, in the future, and **no more than 30 days out** — matching what the legitimate client already sends, closing the gap between "app always sends 30 days" and "rules allow anything."

---

### 5. Org enumeration + PII leak to unapproved accounts — **Low-Moderate**

**Where:** `firestore.rules`, `organizations/{orgId}` `list` rule — the `userPendingApproval()` clause has no `type` filter (unlike the adjacent customer-facing clause, which is scoped to `type == 'supplier'`). `lib/models/enterprise/organization.dart` shows the org doc includes `phone`, `email`, and `address`, not just name/type.

**Impact:** A freshly self-registered, not-yet-approved account can list every active organization of every type platform-wide, including business contact PII, before any vetting occurs. Not fixed in this pass — this is closer to a product/scoping decision (what should be discoverable pre-approval) than a pure bug, and the correct scoping key (`type` intended for the pending user) needs a product decision before a rules change is safe to ship. **Recommend**: either scope this clause by the pending user's intended org type (mirroring the customer clause), or split `phone`/`email`/`address` into a separate document not covered by the pre-approval `list` grant.

---

### 6. Project-deletion grace period is client-enforced only — **Low (no data-loss impact)**

**Where:** `firestore.rules` `projectDeletionFieldsValid()` only requires `deletionScheduledFor > request.time` — no minimum offset — while the UI's 24h "undo delete" grace period (`lib/repositories/project_repository.dart:29`) is enforced purely client-side.

**Verified impact:** confirmed **no** Cloud Function or scheduled job anywhere in the repo actually purges `deletionPending` projects — deletion only flips a status flag hidden by query filters, fully recoverable via `cancelProjectDeletion`. Bypassing the grace period skips a UX cooling-off step; it does not cause irreversible data loss. **Not fixed** — flagging only, since a rules change here has no real security payoff until/unless an actual purge job is introduced (at which point the grace period must be enforced server-side, not just via `> request.time`).

---

### 7. Missing router-level `/admin/**` guard — **Not exploitable, informational only**

**Where:** `lib/router/app_router.dart` has no centralized `platformAdmin` check before rendering admin routes.

**Verified:** every admin screen self-guards via `AdminPlatformGate`/inline claim checks (`hasPlatformAdminClaimProvider`, sourced from the server-signed ID token custom claim, not client-forgeable) and renders no sensitive data before that check resolves. The real data reads are separately enforced by `isPlatformAdmin()` in `firestore.rules`. Worst case for a non-admin hitting `/admin/*` directly is a static "admin required" screen — no data exposure. **No fix required**; noted only as a defense-in-depth suggestion (centralize the guard in the router redirect so future admin screens can't forget to wrap themselves).

---

## Summary

| # | Finding | Severity | Fixed |
|---|---|---|---|
| 1 | Cross-user RFQ draft carryover on shared session | High | ✅ |
| 2 | RFQ resubmit smuggles forged fields via update path | High | ✅ |
| 3 | Legacy items collections — unscoped cross-tenant read | Medium | ✅ |
| 4 | Unbounded invitation expiry | Medium | ✅ |
| 5 | Org enumeration + PII leak to unapproved accounts | Low-Moderate | ⏳ needs product input |
| 6 | Project-deletion grace period client-enforced only | Low | ⏳ no real payoff yet |
| 7 | No router-level `/admin/**` guard | Informational | N/A — not a real vuln |

**Fixed files:**
- `firestore.rules` — scoped legacy item reads, capped invitation expiry, validated customer-branch `approvedQuoteId`/`supplierIdsResponded` changes.
- `lib/providers/rfq_draft_provider.dart` — clear draft state + rotate idempotency key on genuine scope switch.

**Verification performed:**
- `firebase deploy --only firestore:rules --dry-run` — rules compile with no new warnings.
- `firebase emulators:exec --only firestore "flutter test test/firestore_rules_security_test.dart"` — all 79 existing rules tests pass unmodified.

**Not attempted in this pass** (would need a running staging environment + test accounts, out of scope for a static/code-level review): live browser multi-tab session races, actual Firestore REST fuzzing against a deployed project, Storage upload fuzzing (current `storage.rules` blocks all writes outright, so there is currently no upload surface to attack), and large-dataset/Unicode/RTL UI stress testing.
