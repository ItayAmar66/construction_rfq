# Production readiness scorecard

Last updated: Phase 64Z (Hardening Sprint 2).

| Area | Status | Notes |
|------|--------|-------|
| **Product** | Ready | RFQ procurement UX; demo gated to debug; cart wording removed (64D) |
| **UX** | Partial | Hebrew RTL, summaries on cards; full device matrix QA pending |
| **Catalog / search** | Partial | Full category picker + scoped search (64C); **~8400/31551 variants** imported |
| **RFQ lifecycle** | Ready | Catalog + manual, submit, quote, compare, approve, fulfill |
| **Supplier targeting** | Partial | Soft visibility; strict filter not enabled |
| **Security / rules** | Ready | 64A hardening + `SECURITY_NOTES.md`; rules tests |
| **Deploy / import** | Partial | Spark recovery documented (64B/64W); import paused mid-variants |
| **Notifications** | Not shipped | No-op hooks only — see `docs/NOTIFICATIONS_RELEASE.md` |
| **Analytics** | Not shipped | Debug print only — see `docs/ANALYTICS_RELEASE.md` |
| **Roles / admin** | Partial | Rules + helpers; no admin UI — see `docs/AUTH_ROLES_RELEASE.md` |

## Completed hardening (64A–64D, 64J–64Z)

- 64A: Analyzer gate, Firestore security rules
- 64B: Light verify, Spark-safe import config, batch retry
- 64C: Full category picker, category+text search, SKU routing, partial catalog UX
- 64D: Demo gated, RFQ draft language, request summaries, Hebrew errors, README runbook
- 64J–64Y: QA/security docs, regression tests, polish, smoke checklist

## Blockers before public release

1. **Complete catalog import** (~73% variants remaining)
2. Run `TOMORROW_SMOKE_TEST.md` on real Firebase after import
3. `REAL_DEVICE_QA_SCRIPT.md` device matrix sign-off
4. Notification/analytics provider decision (optional for pilot)

## Green gates

- [x] `flutter analyze` — 0 errors
- [x] `flutter test` — green
- [ ] Full production catalog import complete
- [ ] Post-import smoke test pass
- [ ] Staging rules/indexes deployed and verified
