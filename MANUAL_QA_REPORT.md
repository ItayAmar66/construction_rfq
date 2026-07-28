# Manual QA Report — construction_rfq

Branch: `feature/full-project-centric-redesign`
Environment: `flutter build web --release` served locally, driven headlessly (Playwright + Flutter web semantics tree) against the **real** Firebase project `construction-rfq-itay-20-2eee0` (no emulator available in this environment — Java not installed).

**Status: IN PROGRESS.** Session 1 covered Auth (register/login) and the Contractor "create project" entry points via live UI, finding and fixing 4 real bugs (verified against real Firestore data). Session 2 covered Supplier, Contractor (RFQ editing/approve/reject/orders/delivery), Admin, the per-role Permissions matrix, `redirectToLogin`, profile recovery, and catalog units via **code-path tracing** (no browser access in that environment — see Session 2 section below), finding and fixing 2 more real bugs and documenting 5 further issues for a future pass. Still missing: Logout, Forgot Password, Invitation, Pending Approval flows, and a **live click-through** of everything Session 2 verified only by code.

Two notes on the actual seeded QA accounts, since `docs/qa/MANUAL_QA_USERS.md` is **stale** (documents an older seed with different email naming):
- The real current seed data (from `tools/admin/admin_onboarding.js`) uses accounts like `shariki.owner@test.com`, `frishman.pm@test.com`, `afgad.engineer@test.com`, `tubul.sales@test.com`, `dimri.procurement@test.com`, `itay.supplier.owner@test.com`, etc. — run `node tools/admin/manual_qa_inspect.js` (needs `GOOGLE_APPLICATION_CREDENTIALS` or `gcloud auth application-default login`) to get the live list.
- Password for these accounts is **`123123`**, not `Qa123456!` (that fallback password is only used if `123123` is rejected as too weak).

This session also hit two unrelated, uncommitted concurrent edits mid-run (the user was actively working in the same repo in parallel): a temporary `lib/config/app_mode.dart` demo-mode override, and a `lib/screens/customer/customer_requests_screen.dart` compile break (`.valueOrNull` on a non-async provider). Both were confirmed with the user and resolved (see commit `84a1d61` for the compile-break fix, done at the user's request so QA could continue) before proceeding.

---

## Issues found

### 1. [CRITICAL / BLOCKER] — New user registration always fails and deletes the just-created account — FIXED

**Severity:** Critical (blocker) — 100% of new registrations (contractor and supplier) failed. No new user could ever create an account through the public registration form.

**Steps to reproduce (pre-fix):**
1. Go to the login screen → "אין לך חשבון? הירשם" (register).
2. Fill the registration form as a new Contractor: name, phone, email, password, city, contractor company name. Submit ("צור חשבון").
3. Observe the result.

**Expected:** Account created, user lands on the email-verification screen (or directly in the app), with the profile document reflecting what was entered (including the selected size, e.g. "קבלן גדול" / large contractor).

**Actual (pre-fix):** Firebase Auth account was created, but the app immediately routed to a "בעיה בפרופיל" (Profile Problem) screen: "פרופיל המשתמש לא נמצא בשרת" (user profile not found on server). Root cause (confirmed by reading `lib/services/auth_service.dart`): `register()` queries the `organizations` collection (`resolveOrgIdByName`) to pre-match the requested company name *before* writing the caller's own `users/{uid}` profile document — but `firestore.rules` only permits listing `organizations` once that same `users/{uid}` doc already exists (`isCustomer()`/`userPendingApproval()` both require `exists(users/$(uid()))`). The resulting `permission-denied` is caught by the outer error handler, which then **deletes the just-created Auth user** as a "rollback." Net effect: the account is gone, but the UI still shows a message implying the account exists ("החשבון קיים בהתחברות אך חסר מסמך משתמש"), and a subsequent login attempt with the same credentials fails with "אימייל או סיסמה לא נכונים" (email or password incorrect) because the account was deleted.

**Screenshots:**
- `qa_screenshots_tmp/register3.png` — filled registration form (large contractor, all fields valid).
- `qa_screenshots_tmp/register_result2.png` — resulting "Profile Problem" screen after submit.
- `qa_screenshots_tmp/login_result2.png` — subsequent login with the same credentials rejected ("email or password incorrect") because the rollback deleted the account.

**Fix applied (commit `892d44b`):** `lib/services/auth_service.dart` — treat the org-name lookup as best-effort: on any failure (in particular `permission-denied`), continue registration with `matchedOrgId = null` instead of aborting. The pending access-request still carries the requested company name/type, so an admin can match the org manually during approval — this is the same manual-approval path the form already advertises ("הגישה תאושר על ידי מנהל החברה").

**Verified fixed:** Re-ran the same registration flow after the fix + rebuild — account created successfully, no rollback, user correctly lands on "נדרש אימות כתובת מייל" (email verification required) screen with working "resend verification" / "recheck status" / logout actions. See `qa_screenshots_tmp/repro_register.png`.

---

### 2. [LOW] — Profile-recovery screen ignores the user's original account-type selection

**Severity:** Low (cosmetic/UX, only reachable now via the same failure path in a genuine future error, since issue #1's common trigger is fixed).

**Steps:** Trigger the "בעיה בפרופיל" recovery screen (e.g. any future profile-creation failure) after having originally selected a non-default account type/size (e.g. "קבלן גדול" — large contractor) on the registration form.

**Expected:** The recovery form should reflect (or at least not silently contradict) what the user originally selected.

**Actual:** `lib/screens/auth/profile_error_screen.dart` line 24 hardcodes `UserType _userType = UserType.privateCustomer;` — the recovery screen has no memory of the original form's selections (they're discarded when `register()` throws), so it always shows "קבלן (לקוח) · קבלן קטן" regardless of the original choice.

**Not fixed:** low severity, and now rarely reached given fix #1. Flagging for a future pass rather than fixing speculatively.

---

### 3. [HIGH] — Contractor org owners cannot create a project (2 duplicate call sites) — FIXED

**Severity:** High — every org-scoped contractor account (i.e. every seeded QA account, and any real org created via the invitation/admin-approval flow) got a silent permission-denied when creating a project. Only accounts with no org (rare) worked.

**Steps to reproduce (pre-fix):**
1. Log in as an org-scoped contractor owner (e.g. `shariki.owner@test.com` / `123123`).
2. On the home dashboard, click "הוספת פרויקט" (Add Project) — either the quick-action button at the top, or the "+" button in the "פרויקטים" section further down.
3. Fill in project name + address + city, click "שמור פרויקט" (Save Project).

**Expected:** Project created, appears in the project list.

**Actual (pre-fix):** The dialog closed as if it had succeeded, but a toast appeared reading "אין הרשאה לפעולה זו" (no permission for this action), and the project was not created (confirmed by querying Firestore directly). Root cause: `ProjectRepository.createProject()` accepts an optional `orgId`, and `firestore.rules`' `projectCreateRoleAllowed()` needs that `orgId` to check the caller's real org membership (`organizations/{orgId}/memberships/{uid}`) — but **two separate call sites** (`lib/widgets/projects/dashboard_projects_section.dart` and a near-identical duplicate in `lib/screens/customer/customer_dashboard_screen.dart`) never passed it. Without `orgId`, the rule falls back to treating the caller's own uid as a pseudo-org id, which never matches a real org-scoped membership, so the write is always denied for org-scoped accounts.

**Screenshots:** `qa_screenshots_tmp/` was cleared of these during cleanup; re-run via the steps above if visual evidence is needed — behavior is captured above and was verified against real Firestore data (see next line).

**Fix applied (commits `0fe4841`, `8c701be`):** both call sites now pass `ref.read(primaryOrgIdProvider)` as `orgId`.

**Verified fixed:** rebuilt, re-ran the full flow, and confirmed via a direct Firestore read (`tools/admin`) that the new project document was created with the correct `orgId: launch-org-shariki`. Test project was deleted afterward to leave seed data clean.

---

## Auth flows tested so far

| Flow | Result |
|---|---|
| Register (contractor) | **Bug found & fixed** — see issue #1. Verified working post-fix. |
| Login (valid credentials, post-registration-bug account) | Correctly rejected stale/rolled-back credentials with a clear Hebrew error message — this was expected behavior once issue #1's root cause is understood, not a separate bug. |
| Login (pre-seeded QA accounts, e.g. `qa.alpha.owner@test.com`) | **Blocked** — app is currently building in forced demo mode due to the unrelated in-progress `app_mode.dart` edit; login screen correctly refuses real-mode credentials with "במצב הדגמה השתמש בכפתורי ההתחברות לדוגמה" (that refusal itself is correct demo-mode behavior, not a bug). Needs re-test once real-Firebase build is available again. |
| Logout | Not yet tested |
| Forgot Password | Not yet tested |
| Email Verification | Reached the verification-pending screen post-fix; did not verify the resend-email delivery itself (no mailbox access in this environment) or the post-verification unlock path |
| Invitation | Not yet tested |
| Pending Approval | Not yet tested |

## Contractor flows tested so far

| Flow | Result |
|---|---|
| Create Project | **Bug found & fixed** — see issue #3. Verified working post-fix (both entry points) against real Firestore data. |
| Edit Project | Not yet tested |
| Archive Project | Not yet tested |
| Create RFQ / Draft / Send RFQ | Not yet tested |
| Tender | Not yet tested |
| Approve/Reject Quote | Not yet tested |
| Delivery / Receipt | Not yet tested |

## Session 2 (2026-07-28) — Supplier / Contractor / Admin / Permissions

**Environment note:** the Claude-in-Chrome browser extension was not connected in this environment, so this session could **not** click through the live UI the way Session 1 did. Instead, every flow below was verified via **code-path tracing**: reading the actual screen/service/repository implementation for each flow side-by-side with `firestore.rules`, plus running the full automated suite. This is a real, defensible verification method (it catches logic bugs, permission mismatches, and dead code that unit tests miss), but it is **not** a substitute for a live click-through — visual/layout regressions and anything that only manifests at runtime (timing, real Firestore latency, actual screen rendering) are not covered here. A future session with browser access should still do a live pass over these flows.

Also ran, both clean:
- `flutter analyze` → **No issues found.**
- `flutter test` → **All 933 tests passed** (0 failing).

### Issues found this session

**4. [MEDIUM] — Supplier quote unit-of-measure silently dropped before the customer ever sees it — FIXED**

`CatalogProduct.unitType` (kg/m/m²/pcs/etc.) is carried correctly from the catalog through `CatalogRfqLineDraft` and `QuoteRequestItem`, and is shown correctly on the RFQ-builder side (`rfq_draft_line_card.dart`) and the supplier's own response screen. But `SupplierQuoteItem` (`lib/models/supplier_quote_item.dart`) had no unit field at all — the moment a supplier submitted a quote, the unit was lost. The customer-facing quote/compare screens (`customer_quote_line_match_card.dart`, `customer_quote_detail_screen.dart`, `quote_compare_screen.dart`) then showed a bare quantity number with no unit — a real correctness problem for a construction-materials app, where "50" is ambiguous (50 units? 50 kg? 50 m²?).

**Fix applied:** threaded `unitType` end-to-end — `SupplierQuoteItem` (model + `fromEmbedded`/`toEmbeddedMap`/`toMap`), `SupplierQuoteLineInput` in `lib/services/quote_service.dart`, `SupplierQuoteLineMapper.fromRequestLine` (`lib/utils/supplier_quote_line_mapper.dart`) now passes `requestItem.unitType` through, and `customer_quote_line_match_card.dart`'s quantity row now appends the unit when present. Backward compatible — existing quotes without a stored unit render exactly as before (no unit shown).

**Verified:** `flutter analyze` clean, full `flutter test` suite passes (933/933).

**5. [LOW] — Admin org/supplier list sheets show a dead-end chevron — FIXED**

`admin_management_panel.dart`'s "Companies" and "Suppliers" bottom sheets rendered each org row with a `chevron_left` trailing icon implying tap-to-open-detail navigation, but no `onTap` was wired and no detail screen exists — tapping did nothing. Removed the misleading chevron rather than inventing a detail screen that wasn't requested.

**Verified:** `flutter analyze` clean, full test suite passes.

### Flows verified via code-path trace (no code change needed — see method note above)

| Area | Flow | Result |
|---|---|---|
| Supplier | RFQ inbox (`incoming_requests_screen.dart`) | OK |
| Supplier | Tender participation (`tender_bid_screen.dart`) | OK |
| Supplier | Orders / order detail (`supplier_orders_to_fulfill_screen.dart`, `supplier_order_detail_screen.dart`) | OK |
| Supplier | Shipping (`markSupplierOrderShipped`, `quote_service.dart:599-695`) | OK — transactional, matches rules |
| Supplier | Delivery (supplier side) | Confirmed **read-only by design** — delivery confirmation is contractor/customer-side only (`confirmShipmentReceipt`), which is well-guarded. Not a bug. |
| Contractor | RFQ editing (`edit_request_screen.dart`) | OK — transactional with ownership/editability re-checks |
| Contractor | Approve Quote (`quote_service.dart:407-516`, `approval_service.dart`) | OK — transactional re-read blocks double-approval |
| Contractor | Reject Quote (`quote_service.dart:518-597`) | OK — same transactional pattern |
| Contractor | Orders / Delivery receipt (`shipment_receipt_confirmation_screen.dart`) | OK — transactional, gated by `ShipmentReceiptAccess` |
| Admin | Users (`admin_users_screen.dart`) | OK |
| Admin | Permissions (`edit_permissions_dialog.dart`, `team_permissions_policy.dart`) | OK — no self-escalation path, server-equivalent checks before writes |
| Admin | Access Requests (`pending_access_requests_section.dart`, `user_approval_service.dart`) | OK security-wise; minor UX-only gap noted below (not fixed) |
| Admin | Admin Dashboard (`admin_system_cockpit.dart`) | RFQ/order overview and security-settings sections are explicitly stubbed ("coming soon") — intentional, not a bug |
| Permissions | contractorViewer cannot write | Confirmed — no allow-rule or Dart permission includes this role |
| Permissions | Supplier cannot see another org's RFQs/quotes | Confirmed — rules scope correctly by `invitedSupplierIds`/`supplierInvitedByOrg`/`openToAllSuppliers` |
| Permissions | procurementManager can approve quotes | Confirmed, consistent between rules and Dart |
| Permissions | engineer cannot send RFQs | Confirmed blocked both client-side (missing `submitRfq` permission) and server-side (rules reject a forged `status: 'sent'` from non-procurement) |
| `redirectToLogin` | Router guard (`app_router.dart:99-176`, `app_route_guard.dart`) | OK — unauthenticated users redirected pre-build (no flash of protected content); session-revocation via `authSessionProvider` treats permission-denied as sign-out |
| Profile recovery | `profile_error_screen.dart` | OK — reachable via `AuthSession.profileMissing`, offers create/retry/logout, no dead end |
| Catalog units | End-to-end unit consistency | Was the medium bug above; now fixed and verified |

### Bugs found, not fixed this session (documented for a future pass — matches the project's existing pattern of deferring larger transactional rewrites)

- **[MEDIUM]** Supplier quote submission has a non-transactional duplicate-quote check followed by a blind `tx.set()` on a deterministic doc id (`lib/repositories/supplier_quote_repository.dart:227-288`) — a real TOCTOU gap where two concurrent submissions from the same supplier can silently overwrite each other's pricing. Same shape as the races already fixed in commit `ad5cb35` for other flows; needs the same treatment (transactional re-read before write) but was out of scope to fix speculatively this session.
- **[MEDIUM]** Tender counter-bid (`lib/services/quote_service.dart:216-368`, `submitTenderCounterBid`) computes `bidVersion`/`lowestBid` from plain non-transactional reads before `batch.commit()` — concurrent counter-bids can collide on the same doc id and produce a stale `lowestBid`. No idempotency guard exists here, unlike the shipping flow.
- **[LOW]** `ProjectRepository.updateProjectDetails()` (`lib/repositories/project_repository.dart:543-605`) relies solely on `firestore.rules` for the ownership check, unlike its sibling methods (`completeProject`, `requestProjectDeletion`) which run a transactional client-side check too. Works correctly today (rules enforce it), but is inconsistent and gives a worse client-side error message on denial.
- **[LOW]** `ProjectRepository.archiveProject()` (`lib/repositories/project_repository.dart:771-776`) is dead code — it delegates to `completeProject()` but has zero call sites; the actual "complete project" UI action calls `completeProject` directly. Worth confirming with product whether an "Archive" (as distinct from "Complete") UI entry point is actually supposed to exist, or whether this method should simply be deleted.
- **[LOW]** `completeMissingProfile` (`lib/services/auth_service.dart:374-420`, used by profile recovery) does a plain read-then-write rather than a transaction — a narrow concurrent-profile-creation race exists in theory. Low real-world risk since it's a single-user recovery flow.
- **[UX, not a bug]** A losing concurrent access-request-approval attempt surfaces a raw Firestore permission-denied error to the admin rather than a friendly "already approved by someone else" message. Rules correctly prevent the double-approval; only the error message is unpolished.

## Remaining scope (not yet executed)

- **Auth:** Logout, Forgot Password, Invitation, Pending Approval, post-email-verification unlock — still not covered by any session.
- **Live UI click-through** of every flow in this report — this session verified logic/permissions via code, not by operating the actual rendered app. Recommended before final sign-off once browser automation is available again.

## How to resume

1. `flutter build web --release`, serve `build/web` on a free local port (this session used `8899` via `npx serve -s build/web -l 8899` for SPA-fallback routing — **do not use 8765**, an unrelated `manual_replay_trader` service already owns that port on this machine; plain `python -m http.server` does NOT do SPA fallback and will show misleading 404s on any deep-linked route).
2. Log in with the real seeded accounts (see naming note above, password `123123`) rather than registering fresh ones. Live account list as of this session (via `node tools/admin/manual_qa_inspect.js`): `shariki.owner/pm/engineer@test.com`, `frishman.owner/procurement/sales@test.com`, `afgad.owner/pm/engineer/procurement@test.com`, `dimri.owner/pm/engineer/procurement@test.com`, `tubul.owner/sales/procurement@test.com`, `itay.supplier.owner/sales/procurement@test.com`.
3. Note: right after login, the dashboard's permission-gated UI (e.g. the "הוספת פרויקט" button) can take a few seconds to appear as membership/role data resolves — don't mistake that for a missing feature.
4. Continue through the remaining scope above — prioritize a live click-through pass over the flows Session 2 only verified by code.
