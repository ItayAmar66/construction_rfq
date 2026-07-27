# UX Polish Completion Report

Implements the findings in `FIRST_IMPRESSION_AUDIT.md`. No business logic changed; RTL and responsive behavior preserved throughout.

## Verification

- `flutter analyze` — no issues found
- `flutter test` — 926 tests passed (5 pre-existing skips, unrelated to this work)
- `flutter build web` — succeeds (`build/web`)
- No browser automation tool was available in this environment to capture live screenshots; verification here is via analyzer/tests/build plus direct code-path tracing of the reported crash (see below). Recommend a manual click-through on `/catalog` and the dashboard "New Request" button before shipping.

---

## Fixed issues

### 🔴 Critical

**1 & 2 — Dashboard "New Request" and Catalog nav crash to a black dead-end screen**

Root cause found: `FirestoreCatalogSearchRepository` and `FirestoreCatalogRepository` resolved `FirebaseFirestore.instance` **in their constructors**. In demo mode (no `Firebase.initializeApp()` call — e.g. `Firebase not configured` or `Firebase init failed`), that getter throws synchronously. Because the throw happened during Riverpod provider construction (inside a widget `build()`), it landed outside every `try/catch` in the codebase and Flutter rendered it as an uncaught `ErrorWidget` — the black screen the audit saw on both the dashboard's primary CTA and the Catalog nav item (both route to `/catalog`).

Fix: resolve `FirebaseFirestore.instance` lazily via a getter, on first use inside the repositories' `async` methods, so a "Firebase not initialized" error surfaces as a normal `Future` error — which `CatalogSelectorNotifier.initialize()` already catches and turns into a recoverable, retryable `errorMessage` state (the existing "server unavailable" UI, not a crash).
- `lib/repositories/catalog_search/firestore_catalog_search_repository.dart`
- `lib/repositories/catalog/firestore_catalog_repository.dart` (same pattern; also made `watchMeta()` lazy)

**Error boundary itself hardened independently** (per the audit's explicit recommendation to fix this "regardless of root cause"): `lib/utils/bootstrap_error_handling.dart` no longer renders Flutter's black/red dead-end screen for *any* uncaught build error. It now shows an on-brand card with the app's surface color, a clear "not your whole account" message, and two real actions — **חזרה לדף הבית** (home) and **נסה שוב** (retry current route) — both wired through a newly-exported `appRootNavigatorKey` (`lib/router/app_router.dart`) so they work with no local `BuildContext`.

### 🟠 Major

**3 — Desktop whitespace imbalance on request/quote detail**

Both screens are pushed on the root navigator (outside `AppShell`), so they never got the `ContentMaxWidth` treatment every shell route gets for free. Added it explicitly:
- `lib/screens/customer/quote_compare_screen.dart` (the "request detail" screen, opened from בקשות) — capped at 900px, centered
- `lib/screens/customer/customer_quote_detail_screen.dart` — capped at 760px, centered

**4 — "Compare offers" link looked unclickable**

Swapped the bare `TertiaryButton` (unstyled text link) for the app's existing `SecondaryButton` (bordered, navy, full-width, with an icon) — the same component used for every other secondary action in the app, per the audit's own recommendation to match the existing button system.
- `lib/screens/customer/customer_quote_detail_screen.dart`

**5 — Password field looked pre-filled**

Replaced the static `••••••••` hint with neutral placeholder text ("הסיסמה שלך" / "לפחות 6 תווים"), matching how the email field's hint already behaves. Dot-masking now only appears once the user types.
- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/register_screen.dart` (same pattern, fixed for consistency)

**6 — Demo-mode banner reused the warning/amber color**

Recolored both variants of `DemoModeBanner` (the full banner and the compact chip badge) from `AppTheme.amber` to `AppTheme.teal` — an existing palette color already used elsewhere for neutral/informational content, clearly distinct from the app's actual amber warning treatment (e.g. "replaced item" notices, which are untouched).
- `lib/widgets/demo_mode_banner.dart`

### 🟡 Minor

**7 — Unrealistic demo prices**

Seed data in `lib/data/enterprise_demo_scenario.dart` showed totals like ₪42 and ₪50 for "construction material" quotes. Rescaled quantities and unit prices to a believable order of magnitude for the vertical (thousands of shekels: e.g. 220 sacks of adhesive × ₪42 = ₪9,240) while keeping per-unit prices realistic. Request-item quantities were scaled to match so line items stay internally consistent.

**8 — Dense info screens lacked visual grouping**

Added a light `Divider` between the pricing summary and the metadata rows (supplier type, date, notes) inside the quote detail card — a low-cost section break per the audit's own "no redesign" recommendation.
- `lib/screens/customer/customer_quote_detail_screen.dart`

**Error recovery consistency**

The quote-detail screen's inline load-failure state was a bare "error occurred" text with no way forward. Replaced with the app's existing `ErrorMessage` widget (already used elsewhere, e.g. `quote_compare_screen.dart`), which surfaces a real Hebrew message and a retry button.
- `lib/screens/customer/customer_quote_detail_screen.dart`

---

## Remaining UX limitations (not addressed — out of scope or lower priority)

- **No live visual verification.** This environment had no working browser automation, so no before/after screenshots were captured. The crash fix is verified by tracing the exact synchronous throw path and confirming the `try/catch` in `CatalogSelectorNotifier.initialize()` now covers it, plus a clean `flutter analyze`/`flutter test`/`flutter build web`. A manual smoke test of `/catalog` and the dashboard CTA in demo mode is recommended before closing this out.
- **Systemic pattern, narrowly scoped fix.** The same "`FirebaseFirestore.instance`/`FirebaseAuth.instance` resolved eagerly in a constructor" pattern exists in ~15 other repositories/services (`request_repository.dart`, `project_repository.dart`, `auth_service.dart`, etc. — see `grep -rl "?? FirebaseFirestore.instance"`). None of those are reachable from the screens the audit flagged as broken, so they were left as-is to keep this change scoped to the reported findings. Worth a follow-up sweep if demo mode is a supported, ongoing product surface (not just a fallback).
- **Dense-screen grouping (#8) is a spot fix, not a system.** Only the quote-detail card got a section divider. Applying the same "pricing / delivery / supplier" visual grouping across all detail screens would need a small shared component and is a reasonable next design pass rather than a one-line polish item.
- **Demo seed prices are still illustrative, not sourced.** The rescaled numbers (₪9,240 etc.) are plausible construction-material totals but weren't validated against real supplier pricing; if this data is ever used in a live sales demo, a domain expert should sanity-check it once.
- **No dedicated design review.** These are targeted fixes for the specific findings in the audit; a follow-up pass by an actual designer (spacing scale, elevation consistency, icon set) was out of scope here per the "no redesign" instruction.
