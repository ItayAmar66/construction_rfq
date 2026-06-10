# Production readiness — V1 hierarchy sprint

Last updated: V1 completion sprint.

| Area | V1 status |
|------|-----------|
| Catalog | Real Firestore catalog, סל UX, quiet images |
| Projects | Home dashboard, RFQ snapshots, owner-only rules |
| RFQ workflow | Draft/pendingApproval/sent + legacy fallback |
| Permissions | Role matrix + effectivePermissions + legacy userType |
| Admin | Shell + custom claim bootstrap (not client profile) |
| Contractor/supplier shells | ניהול חברה / ניהול ספק |
| Supplier targeting | supplierDirectory read + explicit picker |
| Security rules | Legacy UID + org/project scaffolding |

## Still legacy / not production-complete

- Organization/membership Firestore data not migrated
- Admin console read-only shells
- Custom claims require Admin SDK deploy
- Full org-based Firestore rules not enforced on RFQ writes

## Deploy before real multi-tenant test

1. Firestore rules (projects, supplierDirectory, org helpers)
2. `supplierDirectory` backfill
3. Platform admin custom claim for Itay

See `docs/V1_QA_SCRIPT.md`.
