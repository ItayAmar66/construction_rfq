# Auth Session Fix — Stale Session on Revoked Profile Access

**Reported by:** Final Release Review Board
**Component:** `authSessionProvider` / `AuthService.watchAuthSession()`
**Status:** Fixed

## Bug

`watchAuthSession()` piped Firestore's `users/{uid}` snapshot stream through
`.handleError((error, stack) { if (permission-denied) return; throw error; }).asyncMap(...)`.

`handleError`'s callback returning normally (instead of rethrowing) **suppresses the error but emits nothing** — it does not push a value downstream. Consequences once a user's profile access is revoked (disabled account, membership pulled, security-rules change):

- The Firestore listener errors internally with `permission-denied`.
- The error is swallowed; no new `AuthSession` is ever emitted.
- `authSessionProvider` (a `StreamProvider`) is left holding whatever `AuthSession` it last emitted — typically a fully-authenticated one.
- `resolvedAuthSessionProvider` / `platformAccessGateProvider` never re-evaluate, so `app_router.dart`'s `redirect:` never fires.
- The user stays on whatever screen they were on, now backed by a profile they can no longer read — a broken, stuck screen instead of a redirect to `/login` or `/no-permission`.

## Fix

`lib/services/auth_service.dart`:

- Extracted a new, independently testable function `authSessionFromProfileStream({uid, profileSnapshots, loadClaims})` that turns a raw profile-doc stream into an `AuthSession` stream via `StreamTransformer.fromHandlers`.
- `handleError` now branches:
  - **`permission-denied`** → emits `AuthSession.empty` (the same "signed out" state the router already redirects on) and then **closes the sink**. This is a terminal state for that subscription — Firestore's own listener is already dead after `permission-denied`, so closing our sink too means there's nothing left listening on a dead source (no reconnect loop).
  - **Any other error** → passed through via `sink.addError(...)` unchanged, same as before.
- `handleData` still builds the same `AuthSession` (profile / profile-missing) as before — that code path is untouched, so the existing "profile doc doesn't exist" flow behaves exactly as it did.
- The outer `authStateChanges().asyncExpand(...)` (Firebase Auth listener → per-user Firestore subscription) is unchanged: logout/login still establishes a brand-new profile stream per Firebase-Auth user, so the "one dead subscription" from a permission-denied event never affects a subsequent login.
- Added `ProfileDocEvent`, a small plain-Dart projection of `DocumentSnapshot` (`exists` / `id` / `data`). `DocumentSnapshot` is a sealed class and cannot be faked in tests, so `watchAuthSession()` now maps real snapshots to `ProfileDocEvent` via `.map(ProfileDocEvent.fromSnapshot)` before handing them to the transform — this is the seam that makes the fix unit-testable without a live Firestore instance.

### Requirements checklist

| Requirement | How it's satisfied |
|---|---|
| `permission-denied` must emit `null` | Emits `AuthSession.empty` (`uid == null`, `isAuthenticated == false`) — the session-provider's "no session" value. |
| Existing profile-missing flow must continue | `handleData` / `buildSession` logic for `!doc.exists \|\| doc.data() == null` is byte-for-byte unchanged. |
| No infinite reconnect loop | `sink.close()` on permission-denied; no retry/resubscribe logic was added. |
| Preserve auth listener behavior | `authStateChanges().asyncExpand(...)` outer chain untouched. |
| Preserve performance | Same single Firestore listener per signed-in user; no polling, no extra reads, no extra `getIdTokenResult()` calls beyond the existing one per snapshot. |

## Tests

Added `test/auth_session_fix_test.dart`, exercising `authSessionFromProfileStream` directly with fake `ProfileDocEvent` streams and errors (no Firestore emulator needed):

1. **Disabled account** — `permission-denied` on first event emits exactly `AuthSession.empty`, no error propagates to listeners.
2. **Revoked membership** — a prior valid, authenticated session followed by `permission-denied` transitions to `AuthSession.empty` (proves the fix, not just the empty-stream case — this is the actual regression scenario).
3. **Deleted profile** — `exists: false` still produces `profileMissing: true` (unchanged behavior, not misrouted through the permission-denied branch).
4. **Permission denied → no reconnect loop** — asserts the sink actually closes (`onDone` fires) after the empty session is emitted.
5. **Reconnect** — a fresh `authSessionFromProfileStream` subscription (simulating the outer listener re-establishing a stream, e.g. after rules are fixed or re-login) yields a normal live session again; the earlier subscription's terminal state doesn't leak forward.
6. **Logout / login again** — two independent subscriptions for two different uids (`user-a` then `user-b`) confirm no state bleeds between a permission-denied session and a subsequent, different user's session.
7. (Bonus, not in the required list but validates the fix doesn't over-broaden) **Non-permission Firestore errors still propagate** — e.g. `unavailable` is not swallowed, still reaches `onError`.

All 933 existing tests in the suite continue to pass — no other auth/router/membership tests needed changes.

## Verification run

```
$ flutter analyze
No issues found!

$ flutter test
00:26 +933: All tests passed!
```
