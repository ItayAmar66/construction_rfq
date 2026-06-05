# Production readiness scorecard

Last updated: Sprint Long Night (Phases 44–60).

| Area | Status | Notes |
|------|--------|-------|
| **Product / RFQ lifecycle** | Ready | Catalog + manual, quote, compare, approve, ship — demo + tests |
| **UX / procurement UI** | Partial | Key screens polished; not full design system |
| **Catalog / search** | Partial | Firestore MVP OK; external search not wired |
| **Supplier targeting** | Partial | Soft labels live; strict cutover planned |
| **Security / Firestore rules** | Ready | Catalog read-only, rules tests, embedded snapshot fields |
| **Deploy / import** | Partial | Checklist + emulator gate; no prod import automation |
| **Notifications** | Not ready | No-op hooks only |
| **Analytics** | Partial | Catalog RFQ events; no full funnel |
| **Roles / permissions** | Partial | Helpers added; no RBAC enforcement in rules |
| **Admin catalog** | Not ready | Plan only; debug ops read-only |
| **Audit / history** | Partial | Audit trail + read model foundation |

## Next priorities

1. External search adapter + Typesense/Algolia pilot index
2. Targeting cutover Phase B (request flag + supplier filter)
3. Notification provider integration (email/push)
4. Role enforcement in Firestore rules for enterprise tenants
5. Staging catalog import with rollback drill

## Green gates before production demo

- [ ] `flutter analyze` + `flutter test` green
- [ ] `COMPANY_DEMO_QA_CHECKLIST.md` passed
- [ ] `run_emulator_gate.sh` PASS on target dataset
- [ ] Rules/indexes deployed to staging (not prod without approval)
