# Production Reliability Report

**Branch:** `feature/full-project-centric-redesign`
**Date:** 2026-07-28
**Scope:** offline/reconnect, refresh-during-submit, browser close/crash, duplicate submit, retry storms, session expiration, simultaneous edits / two-tab races, slow network, cancelled requests, large uploads.

`flutter analyze`: clean (no issues). `flutter test`: 926 passed / 5 skipped, no regressions (one pre-existing broken assertion fixed — see issue #5 below).

---

## What was already solid (verified, not re-fixed)

- **Offline / draft persistence / duplicate-submit on the RFQ cart** (`lib/providers/rfq_draft_provider.dart`, `lib/screens/customer/cart_screen.dart`): drafts persist to `SharedPreferences`, submit uses a stable `clientOperationId` as the Firestore doc id so a refresh-during-submit or a retried tap re-writes the same document instead of creating a duplicate RFQ, and a connectivity-aware banner distinguishes "offline/queued" from "sent." (Shipped in commit `8c331de`.)
- **Session/auth handling**: `AuthService.watchAuthSession` timeboxes token-claim reads (8s) and treats `permission-denied` on the profile stream as "keep waiting," not a crash. Every repository's `.snapshots()` stream has a `handleError` guard. `app_router.dart`'s redirect logic fully covers loading/error/unauthenticated/profile-missing/gate states — no dead-end or blank screen on session loss.
- **No file/photo upload feature exists in the app** (no `image_picker`/`file_picker`/Storage upload call sites in `lib/`) — "large upload" and "cancelled upload" scenarios don't apply; noted rather than forced.
- **Catalog search debounce**: `CatalogSelectorScreen` cancels its 300 ms search timer on dispose and guards with `mounted`, so navigating away mid-type is safe.
- Several quote/order write paths already use transactions or batches from an earlier hardening pass (`rejectCustomerQuote`, cancel-RFQ quote retirement, `submitTenderCounterBid`'s batch folding) — not touched again here.

---

## Issues found and fixed

### 1. Stale search response overwrites newer one (race, slow network)
- **Severity:** Medium
- **File:** `lib/providers/catalog_selector_provider.dart` (`_refreshResults`, `loadMore`)
- **Repro:** On a slow/throttled connection, type a search term, then immediately switch category (or clear the search) before the first request resolves. Two `_fetchPage()` calls are now in flight; whichever resolves *last* wins the `state.hits`, even if it's the stale one — the user sees results for a filter they no longer have selected.
- **Fix:** Added a monotonically increasing `_refreshRequestId` guard. Each `_refreshResults`/`loadMore` call captures the id it was issued under and discards its result if a newer refresh has since started. Also resets a would-be-stuck `isLoadingMore` flag when a fresh search interrupts an in-flight "load more."

### 2. Concurrent quote/order/RFQ status transitions overwrite each other (lost updates)
- **Severity:** High
- **Files:** `lib/services/quote_service.dart` (`markSupplierOrderShipped`, `confirmShipmentReceipt`), `lib/repositories/request_repository.dart` (`approveProcurementRequest`, `rejectProcurementRequest`, `sendPendingApprovalToSuppliers`, `updateQuoteRequest`), `lib/repositories/project_repository.dart` (`completeProject`, `requestProjectDeletion`, `cancelProjectDeletion`)
- **Repro (example — two browser tabs):** Two procurement reviewers open the same RFQ; one clicks "Approve," the other "Reject" within the same second. Both read `status == pendingApproval` before either write lands, both pass the guard, and whichever `.update()` commits last silently wins — but **both** audit-log entries get written, so the losing reviewer sees no error and believes their action succeeded. Similar lost-update races existed for: two teammates both marking the same order "shipped" (second overwrites the first's tracking number), two people confirming receipt on the same request (second overwrites the checklist), two "send to suppliers" calls with different supplier selections (second drops the first's chosen suppliers), and an owner completing a project in one tab while requesting its deletion in another.
- **Fix:** Converted each of these read-check-write sequences from plain `.get()` + `.update()`/batch to `FirebaseFirestore.runTransaction`, re-reading and re-validating the status/guard condition *inside* the transaction. The loser of a race now gets a re-read that reflects the winner's just-committed state and fails its own guard cleanly (a normal, user-facing error) instead of silently clobbering data. No Firestore rules changes were needed — all touched documents are single-doc read/writes against refs the caller already holds, and the update payloads are unchanged.

### 3. Duplicate-submit risk on unguarded buttons (double-tap / slow network)
- **Severity:** Medium-High (creates duplicate writes/audit entries, not just a UI glitch)
- **Files & fixes:**
  - `lib/widgets/permissions/pending_access_requests_section.dart` — `_PendingRequestCard` converted to a stateful widget with a `_busy` guard on "דחה" (reject); `ApproveUserDialog`'s "אשר" button now tracks its own `busy` flag (disables both dialog buttons and shows a loading spinner during the write).
  - `lib/screens/admin/admin_console_screen.dart` — `AdminConsoleScreen` converted to `ConsumerStatefulWidget` with a `_processingUserIds` set so "אשר כמנהל חברה/ספק" can't be double-tapped per-user while the approval write is in flight.
  - `lib/screens/customer/quote_compare_screen.dart` — `_RequestActions` converted to a stateful widget with a `_busy` guard shared across "מחק" (delete/cancel), "סגור מכרז" (close tender), and "שכפל בקשה" (duplicate request), so a fast double-tap (very plausible right after a confirm dialog closes) can no longer fire the same write twice.
- **Fix pattern:** matches the `_busy`/`isLoading` convention already used elsewhere in the codebase (e.g. `shipment_receipt_confirmation_screen.dart`, `cart_screen.dart`) — disable the trigger, run the write, re-enable in a `finally`/error branch.

### 4. Raw exception text shown to users on write failure
- **Severity:** Low (UX/polish, but directly relevant to session-expiration and permission-denied clarity)
- **Files:** `lib/screens/admin/admin_company_detail_screen.dart`, `lib/screens/admin/admin_management_panel.dart`, `lib/widgets/permissions/pending_access_requests_section.dart`
- **Repro:** If a write fails because the caller's session/claims changed (e.g. a permission was revoked mid-session) or the network dropped, these three save/approve dialogs showed `e.toString()` — a raw `[cloud_firestore/permission-denied] ...` string — instead of the app's existing Hebrew user-facing error mapping.
- **Fix:** Replaced `Text(e.toString())` with `Text(userFacingError(e))`, reusing the existing `lib/utils/user_facing_error.dart` helper (already used consistently elsewhere) that maps Firebase exceptions/network errors to Hebrew messages.

### 5. Broken recoverable-crash-screen test + button overflow (browser-crash scenario)
- **Severity:** Medium — this is exactly the UI shown on the "browser crash" / uncaught-widget-exception test case
- **File:** `lib/utils/bootstrap_error_handling.dart`, `test/organization_membership_watcher_test.dart`
- **Found:** The working tree already contained an in-progress redesign of `ErrorWidget.builder` (wrapping the crash screen in `_AppErrorScreen` with "נסה שוב"/"חזרה לדף הבית" recovery actions) that (a) broke the existing unit test, which asserted the builder returns a bare `Material` and now got a wrapper widget instead, and (b) laid out its two recovery buttons in a `Row(mainAxisSize: min)` inside a max-360px box — overflowing by 66px on a narrow viewport (confirmed via widget test at default test-harness size).
- **Fix:** Updated the test to a `testWidgets` case that pumps the widget and asserts on its actual rendered contract (a `Material` is present somewhere in the tree, the title text renders, and both recovery buttons are present) instead of the exact root type. Changed the button `Row` to a `Wrap` so the two actions reflow onto a second line instead of overflowing on narrow/mobile viewports.

---

## Remaining risks (found, not fixed this pass)

These require either a data-model change, a Firestore rules change, or are bounded by a real SDK limitation (`Transaction.get()` only accepts document references, not queries) — flagged for a follow-up session rather than fixed blind:

- **`lib/repositories/organization_repository.dart` `updateMemberRole`** — last-owner-demotion guard counts owners via a plain collection query outside any transaction. Two admins simultaneously demoting the org's last two owners can both pass the "≥1 owner remains" check and leave the org with zero owners. A transactional fix would need every member doc read via `tx.get()` (bounded by member-list size) rather than a query — worth doing but is a larger, riskier change than a single-doc transaction.
- **`lib/services/user_approval_service.dart` `approveAccessRequest` / `rejectAccessRequest`** — the access-request's own `status` field is never re-checked before acting, and the membership-granting transaction is decoupled from the `resolveRequest` status write. Two admins approving vs. rejecting the same request within the same window can leave a user with an active membership while the request is recorded "rejected." Needs the two writes folded into one transaction plus a status precondition — deferred as a multi-step behavioral change, not a mechanical fix.
- **`lib/repositories/request_repository.dart` `deleteOrCancelQuoteRequest`** and **`lib/repositories/supplier_quote_repository.dart` `submitSupplierQuote`** — both read a *query* result (child quotes / duplicate-quote check) before writing; Firestore transactions don't support query reads, so a full atomic fix isn't a drop-in `runTransaction` wrap. This matches a previously-documented finding (see project memory `data-integrity-review-2026-07-24`) that this needs a data-model or backend (Cloud Function) change to close completely.
- **Tender counter-bid `lowestBid` aggregate** (`quote_service.dart` `submitTenderCounterBid`) can go stale under two suppliers bidding in the same instant, since it's computed from a pre-write query snapshot. Same query-in-transaction limitation as above.
- **No automated test coverage for the new transactional races** — the fixes in this report were verified by code inspection (transaction re-read now sees the winner's committed state) and the existing `flutter test` suite (which runs rules-less against `MockStore`/fakes and doesn't exercise real Firestore transaction contention). An emulator-based concurrency test (two clients racing a `runTransaction` call) would give much stronger confidence but requires the Java/emulator toolchain this environment doesn't have (see project memory `permissions-overhaul-status`).
- **`lib/screens/contractor/contractor_company_screen.dart` / `supplier_company_screen.dart`** resend/cancel-invite buttons and **`lib/widgets/projects/dashboard_projects_section.dart`** create/edit-project dialogs still lack busy guards — lower severity (resend-invite double-send is an annoyance, not data corruption; duplicate-project-create is unlikely since it requires re-opening the dialog) — left for a follow-up pass given time budget.
