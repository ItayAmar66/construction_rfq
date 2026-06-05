# Production readiness scorecard

Last updated: Phase 60 recovery (post Phases 44–59, HEAD recovery).

| Area | Status | Notes |
|------|--------|-------|
| **Product** | Ready | Procurement-focused RFQ app; demo + manual QA scripts; no e-commerce scope creep |
| **UX** | Partial | Key screens polished (Phases 44–50); not a full design system or device matrix sign-off |
| **Catalog / search** | Partial | Firestore MVP + import pipeline; external search adapter skeleton only (no SDK wired) |
| **RFQ lifecycle** | Ready | Catalog + manual items, submit, quote, compare, approve, fulfill; repos + approval service extracted |
| **Supplier targeting** | Partial | Soft visibility + cutover plan; strict category/supplier filter not enabled |
| **Security / rules** | Ready | Firestore rules + tests; catalog read-only in prod paths; embedded snapshot fields |
| **Deploy / import** | Partial | Checklist, emulator gate, staging steps documented; no automated prod import/rollback drill |
| **Notifications** | Partial | No-op RFQ event hooks + payload tests; no email/push provider |
| **Analytics** | Partial | Catalog RFQ events tracked; no full funnel or production dashboard |
| **Roles** | Partial | Role permission helpers + docs; login unchanged; no RBAC enforcement in Firestore rules |

## Next priorities

1. Run `REAL_DEVICE_QA_SCRIPT.md` and `COMPANY_DEMO_QA_CHECKLIST.md` on target device/web
2. Supplier targeting cutover Phase B (request flag + filtered supplier inbox)
3. External search pilot (Typesense per `CATALOG_SEARCH_PRODUCTION_DECISION.md`)
4. Notification provider behind existing hooks (RFQ sent, quote received, approved, shipped)
5. Role enforcement in Firestore rules for enterprise tenants
6. Staging catalog import + rollback drill per `CATALOG_PRODUCTION_DEPLOY_CHECKLIST.md`

## Green gates before production demo

- [ ] `flutter analyze` + `flutter test` green
- [ ] `run_emulator_gate.sh` PASS on target dataset
- [ ] Rules and indexes deployed to staging (not prod without approval)
- [ ] `PRODUCTION_READINESS_SCORECARD.md` reviewed with stakeholders
