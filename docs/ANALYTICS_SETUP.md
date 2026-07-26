# Product analytics (Firebase Analytics) — setup status

## Done in code (this repo)

- `lib/analytics/app_analytics.dart` — `AppAnalytics.track(name, params)`,
  same shape as the pre-existing `CatalogRfqAnalytics` (kept separate/
  unchanged). `NoOpAppAnalytics` (default), `DebugAppAnalytics` (prints in
  debug builds), `FirebaseAppAnalytics` (forwards to
  `FirebaseAnalytics.instance.logEvent`, coercing non-primitive param values
  to strings defensively rather than throwing).
- Gated by `FeatureFlags.analyticsEnabled` — a pre-existing flag in
  `lib/config/feature_flags.dart` that was defined but never read anywhere
  in the app before this change. Reads `FEATURE_ANALYTICS` at build time.
  Off in demo mode regardless of the flag (`useFirebase` check).
- Unlike Crashlytics, Firebase Analytics supports Flutter web, so there is
  no platform exclusion here.
- Wired in `lib/main.dart` via a Riverpod provider override
  (`appAnalyticsProvider`) resolved once before `runApp`.
- `AppAnalyticsEvents` (`lib/analytics/app_analytics.dart`) defines the
  closed-beta funnel — the only 16 events the app sends:
  `registration_started/completed`, `email_verification_completed`,
  `invitation_opened/accepted/failed`, `project_created`,
  `rfq_draft_started`, `rfq_sent`, `supplier_viewed_rfq`,
  `quote_submitted`, `quote_approved/rejected`, `order_shipped`,
  `delivery_confirmed`, `support_opened`.
- Call sites are all at the post-success point of the corresponding action
  (registration, verification check, invite accept flow, project creation,
  first RFQ draft item, RFQ submit, supplier request-list open, quote
  submit for both normal and tender bids, quote approve/reject, mark
  shipped, confirm receipt). `support_opened` is wired in the Phase 6
  support-contact change (see docs/SUPPORT_CONTACT.md).
- Every param is a short categorical value (status/role string, count, or
  boolean) — no names, emails, phone numbers, free text, or full document
  ids. See the privacy review notes below.
- Tests: `test/app_analytics_test.dart` (selection matrix, event-name
  uniqueness, NoOp/Debug safety, sink recording).

## Still required — owner action, not verifiable from code

1. **Enable Google Analytics for the Firebase project** in the Firebase
   console (Analytics must be linked to the project before events appear —
   this is separate from the app-side wiring).
2. **Build flag**: ship with `--dart-define=FEATURE_ANALYTICS=true` for
   staging/prod builds only.
3. **Verify events land**: use the Firebase console's DebugView
   (`adb shell setprop debug.firebase.analytics.app <package>` on Android,
   or the web debug extension) to confirm events appear in real time on a
   test build — not verified end-to-end in this session (no device/build
   available in this environment).
4. **Funnel/conversion reports**: once events are flowing, configure the
   funnel in the Analytics console (registration → verification →
   first RFQ → first quote → first delivery) — this is console
   configuration, not code.
