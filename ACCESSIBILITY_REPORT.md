# Accessibility Audit & Fixes

Date: 2026-07-28
Branch: `feature/full-project-centric-redesign`
Scope: keyboard navigation, focus order, tab order, screen readers, semantics,
contrast, RTL accessibility, mobile/desktop accessibility, touch targets,
responsive accessibility.

## Method

Three parallel audits covered the `lib/` tree (~396 Dart files):

1. Screen readers / semantics (`Semantics`, tooltips, labels, live regions).
2. Keyboard navigation, focus order, tab order, dialog focus/escape behavior.
3. Color contrast (WCAG AA), RTL correctness, touch target size.

Findings were verified against the source before any fix was applied. Fixes
below are limited to changes that are safe (no behavior change beyond
accessibility), scoped, and testable with `flutter analyze` / `flutter test`.

## Baseline

- `Semantics(`, `MergeSemantics`, `ExcludeSemantics` — **0 matches** anywhere
  in `lib/` before this pass. All prior a11y support was implicit (default
  Material widget semantics only).
- App-level RTL setup (`lib/main.dart`) was already solid: Hebrew locale,
  `Directionality(TextDirection.rtl)`, and a deliberate `arrow_forward`
  (not `arrow_back`) back icon since "back" points right in RTL.
- No custom checkbox/radio/switch widgets — all selection UI uses Flutter's
  built-in `Checkbox`/`ChoiceChip`/`FilterChip`, which carry correct default
  semantics. No action needed there.

## Fixes applied

### Screen readers / semantics
- Added `tooltip:` (`HebrewStrings.increaseQuantity` /
  `decreaseQuantity`) to all 4 duplicated hand-rolled quantity-stepper
  `IconButton` pairs, previously icon-only with no accessible name:
  `product_detail_screen.dart`, `manual_rfq_item_dialog.dart`,
  `rfq_draft_line_card.dart`, `catalog_variant_detail_sheet.dart`. The
  adjacent quantity `Text` is now wrapped in `Semantics(liveRegion: true)`
  so screen readers announce the new value after each tap.
- Wrapped `CircularProgressIndicator` in `Semantics(label: 'טוען...')` in
  `loading_view.dart` and the three shared design-system buttons
  (`primary_button.dart`, `secondary_button.dart`, `tertiary_button.dart`),
  covering the large majority of loading states app-wide from 4 files.
  `loading_view.dart`'s decorative spinner/text are also marked
  `ExcludeSemantics` since the parent `Semantics.label` already carries the
  full announcement.
- `AppTextField` instances in `login_screen.dart` and `register_screen.dart`
  relied on a visually-adjacent `AuthFieldLabel` `Text` with no semantic
  link to the input; a screen reader landing on the field announced only
  the placeholder (or nothing on 2 fields with no hint at all). Wrapped each
  field in `Semantics(label: <field name>)` so the accessible name matches
  the visible label, covering 10 fields across both auth screens.

### Keyboard navigation / focus order / tab order
- `SecondaryAppBar`'s breadcrumb trail (`app_back_leading.dart`) used a bare
  `GestureDetector` — not part of the focus tree, so keyboard/switch users
  could not tab to or activate it. Replaced with `Material` +
  `InkWell` (matching every other tappable control in the app), which is
  focusable and keyboard-activatable (Enter/Space) out of the box. Items
  with no `onTap` render as plain, non-focusable `Text` (they're the current
  page, correctly excluded from tab order).
- Added `textInputAction`/focus chaining (`FocusNode` + `onFieldSubmitted` →
  `FocusScope.of(context).requestFocus(...)`) so Enter/next moves through
  fields instead of dismissing the keyboard, across the app's largest forms:
  `register_screen.dart` (8 fields), `profile_error_screen.dart` (3),
  `profile_screen.dart` (4), `tender_bid_screen.dart` (2),
  `supplier_quote_response_screen.dart` (2), and the inline edit dialog in
  `admin_company_detail_screen.dart` (3). Terminal fields use
  `TextInputAction.done`.
- Dynamic per-row list forms (`shipment_receipt_confirmation_screen.dart`)
  were left on default traversal — each row is an independent group, not a
  sequential flow, so chaining would not add value there.

### Contrast (WCAG AA)
- `AppTheme.amberDark` (`#B4720A`) only reached ~3.5:1 against its usual
  `amberSurface` background and ~3.9:1 against white — failing the 4.5:1
  requirement for normal-size badge/label text. It is used exclusively as a
  text/icon foreground color (never as a background or border) in ~20 call
  sites app-wide (status chips, badges, icons), so it was safe to redefine
  in one place. Darkened to `#7A4E00` (7.2:1 vs white, 6.4:1 vs
  `amberSurface`), fixing every dependent call site at once with no other
  visual-role change.
- `StatusChip.tender` and `StatusChip.scope(RoleScopeType.supplier)` used
  raw `AppTheme.amber` (`#E8912A`, 2.47:1 vs white — fails even the 3:1
  large-text/icon floor) as foreground text. Switched both to the now-fixed
  `AppTheme.amberDark`.
- Three large (64px) status-icon usages of raw `amber` — the "warning"/
  "email" icons in `verify_email_screen.dart`, `membership_load_error_screen.dart`,
  and `profile_error_screen.dart` — switched to `amberDark` for the same
  reason (icons conveying meaning need ≥3:1, previously well under that).
- Chart/gradient/border/selected-nav-indicator uses of `amber` were left
  unchanged — those are decorative or compared against a legend, not text
  needing a contrast ratio, and a broad recolor there would be a larger,
  unreviewed visual change out of scope for a safe pass.

### Touch targets
- Quantity-stepper `_StepButton` (`catalog_quantity_stepper.dart`) had an
  explicit `minimumSize: Size(36, 36)` — below the 44×48dp minimum.
  Increased to `Size(44, 44)`.
- The register screen's close (`X`) `IconButton` used
  `visualDensity: VisualDensity.compact`, shrinking the default 48×48 target
  to ~40×40. Removed the compact density.
- The project-card edit `IconButton` in `dashboard_projects_section.dart`
  used `visualDensity: VisualDensity.compact` with no minimum size override;
  added an explicit `minimumSize: Size(44, 44)` while keeping the visually
  compact icon.
- Audited every other `VisualDensity.compact` usage found by the audit
  (`demo_mode_banner.dart`, `quote_match_summary_chips.dart`,
  `quote_request_catalog_snapshot.dart`, `pending_invitations_section.dart`,
  `project_team_hierarchy_section.dart`, `quote_comparison_matrix.dart`,
  `rfq_draft_line_card.dart`'s matched-badge chip) — all are static `Chip`
  badges with no `onTap`/`onPressed`/`onDeleted`, so WCAG's touch-target
  requirement (which applies to interactive controls) does not apply; left
  unchanged.

### RTL
- `delivery_widgets.dart`'s filter-chip row used
  `EdgeInsets.only(left: 8)` for inter-chip spacing in a horizontally
  scrolling `Row` — a physical-side offset that would sit on the wrong side
  if the app ever ran LTR. Changed to
  `EdgeInsetsDirectional.only(end: 8)`.
- Other RTL findings from the audit (a few symmetric `EdgeInsets.only`, one
  hardcoded `Alignment.centerRight`, one hardcoded gradient direction) are
  harmless today because the app is Hebrew-only/RTL-only, and changing them
  broadly would touch many files for no user-visible effect; left as
  low-priority notes below rather than "fixed."

## Verified but not changed (non-issues)

- No `MouseRegion`/hover-only affordances anywhere in `lib/`.
- No orphan icon-only tappable widget with zero adjacent text and zero
  tooltip (the closest cases were the quantity steppers, now fixed above).
- `PrimaryButton`/`SecondaryButton`/`TertiaryButton`/`AppCard`/`V2StatCard`
  are all built on real Material button/`InkWell`-in-`Material` primitives,
  so they're focusable and keyboard-activatable by default — no wrapper
  needed.

## Deferred (lower priority, flagged for a follow-up pass)

- `AppCard`, `DashboardTile`, `V2StatCard` don't accept an explicit
  `semanticLabel` — for icon/number-only content this can leave a screen
  reader announcing raw visual content instead of a synthesized purpose.
  Needs a small API addition (`semanticLabel` param), not just a call-site
  fix, so left out of this safe pass.
- Of 28 `showDialog` call sites, only 10 set `barrierDismissible: false`;
  the remaining 18 default to `true`, so Escape-key dismissal is
  inconsistent between confirmation dialogs and informational ones. Only
  one dialog (`manual_rfq_item_dialog.dart`) auto-focuses its first field.
  This needs a per-dialog product decision (which should be Escape-
  dismissible), not a mechanical fix.
- Chart/decorative/border uses of `AppTheme.amber` and the broader
  `EdgeInsets` → `EdgeInsetsDirectional` sweep noted above.

## Verification

- `flutter analyze` — **no issues found**.
- `flutter test` — full suite run; all tests pass **except** one pre-existing
  failure (`test/organization_membership_watcher_test.dart`:
  `BootstrapErrorHandling installs Hebrew error widget`) that is unrelated
  to this accessibility work. It comes from an in-progress, uncommitted
  change to `lib/utils/bootstrap_error_handling.dart` already present in the
  working tree before this pass started (replacing the crash `ErrorWidget`
  with a new `_AppErrorScreen`, which the existing test hasn't been updated
  for yet). Confirmed by stashing all working-tree changes and re-running
  the test in isolation — it passes against the last commit and fails only
  once that unrelated change is present.
