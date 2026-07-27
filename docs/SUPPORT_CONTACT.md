# Support contact & legal placeholders — setup status

## Done in code (this repo)

- `lib/config/app_config.dart` — `companyLegalName` and `supportEmail` are
  now build-time `--dart-define` values (`COMPANY_LEGAL_NAME`,
  `SUPPORT_EMAIL`), not hardcoded strings. Defaults are honest placeholders,
  not fabricated legal/contact info: `companyLegalName` defaults to a
  beta-labeled team name, `supportEmail` defaults to **empty** —
  deliberately, since inventing an email domain nobody owns could silently
  misdirect a real user's bug report.
- `lib/utils/legal_content.dart` — privacy policy / terms now interpolate
  those config values instead of literal `[שם החברה]` / `[support@example.com]`
  brackets, and both documents now open with an explicit
  `betaDraftNotice` ("this is a closed-beta draft, not final, pending legal
  review") so nothing reads as authoritative before real legal review.
- `lib/utils/support_contact.dart` — single `openSupportContact(context, ref)`
  entry point for every "contact support" action:
  - If `SUPPORT_EMAIL` is configured: opens a prefilled `mailto:` with app
    version, environment, and platform (via the new `PlatformLabel` util) —
    no names/emails/document ids.
  - If not configured (today's default): copies the same diagnostic text to
    the clipboard and tells the user to share it with whoever invited them,
    instead of a dead mailto link.
  - Tracks `AppAnalyticsEvents.supportOpened` either way.
- Wired into `lib/screens/profile/about_legal_screen.dart` (new "פנה
  לתמיכה" row) and `lib/screens/auth/no_permission_screen.dart` (new
  support button alongside the existing logout action) — the two places
  users most plausibly need it.
- Tests: `test/legal_config_validation_test.dart` (guards against ever
  regressing to a literal bracket placeholder or `example.com`),
  `test/support_contact_test.dart` (action fires, tracks analytics, never
  throws).

## Still required — owner action, not verifiable from code

1. **Provide the real support email** and ship with
   `--dart-define=SUPPORT_EMAIL=<real address>` — until then, users get the
   clipboard-copy fallback, not a direct email.
2. **Provide the real legal entity name** once decided, via
   `--dart-define=COMPANY_LEGAL_NAME=<name>`.
3. **Legal review** of `docs/legal/` and `LegalContent.privacyPolicy` /
   `termsOfService` before removing the beta-draft notice — the notice is a
   deliberate safeguard, not a bug to "fix" by deleting it.
4. Consider whether the mailto fallback is sufficient for beta, or whether
   a real support ticketing channel is needed before wider rollout — out of
   scope for this change.
