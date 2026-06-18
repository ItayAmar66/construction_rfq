# Manual QA Users — Clean Seed

**Live URL:** https://construction-rfq-itay-20-2eee0.web.app/

**Password (all QA users below):** `Qa123456!`

**Admin users preserved (not in matrix):**

| Email | Notes |
|-------|-------|
| admin@admin.com | Platform admin |
| itayamar206@gmail.com | Admin account |

---

## Contractor Alpha — בדיקות קבלן אלפא בע"מ

**Org ID:** `qa-org-contractor-alpha`  
**Project:** בדיקות פרויקט אלפא (`qa-proj-alpha`)

| Email | Role | Label |
|-------|------|-------|
| qa.alpha.owner@test.com | contractorCompanyOwner | מנהל חברה |
| qa.alpha.procurement1@test.com | procurementManager | רכש 1 |
| qa.alpha.procurement2@test.com | procurementManager | רכש 2 |
| qa.alpha.engineer1@test.com | engineer | מהנדס 1 |
| qa.alpha.engineer2@test.com | engineer | מהנדס 2 |
| qa.alpha.viewer@test.com | contractorViewer | צפייה בלבד |

## Contractor Beta — בדיקות קבלן בטא בע"מ

**Org ID:** `qa-org-contractor-beta`  
**Project:** בדיקות פרויקט בטא (`qa-proj-beta`)

| Email | Role | Label |
|-------|------|-------|
| qa.beta.owner@test.com | contractorCompanyOwner | מנהל חברה |
| qa.beta.procurement@test.com | procurementManager | רכש |
| qa.beta.engineer@test.com | engineer | מהנדס |

---

## Supplier A — בדיקות ספק גדול בע"מ

**Org ID:** `qa-org-supplier-a`

| Email | Role | Label |
|-------|------|-------|
| qa.supplierA.owner@test.com | supplierOwner | מנהל ספק |
| qa.supplierA.sales1@test.com | supplierSalesRep | איש מכירות |
| qa.supplierA.viewer@test.com | supplierViewer | צפייה בלבד |

## Supplier B — בדיקות ספק קטן בע"מ

**Org ID:** `qa-org-supplier-b`

| Email | Role | Label |
|-------|------|-------|
| qa.supplierB.owner@test.com | supplierOwner | מנהל ספק |
| qa.supplierB.sales@test.com | supplierSalesRep | איש מכירות |

## Supplier C — בדיקות ספק לא מוזמן בע"מ

**Org ID:** `qa-org-supplier-c` (not invited in default flows)

| Email | Role | Label |
|-------|------|-------|
| qa.supplierC.owner@test.com | supplierOwner | מנהל ספק |

---

## Special accounts

| Email | Expected behavior |
|-------|-------------------|
| qa.noaccess@test.com | Active user doc, **no membership** → אין לך הרשאות למערכת |
| qa.pending@test.com | `accountStatus: pendingApproval` → should not enter app |

---

## Suggested manual test flows

1. **Engineer → procurement → suppliers** — Login as `qa.alpha.engineer1@test.com`, create RFQ on פרויקט אלפא → `qa.alpha.procurement1@test.com` approves and sends to Supplier A + B.
2. **Supplier quotes** — `qa.supplierA.owner@test.com`: total **12345**, delivery **7 ימים**. `qa.supplierB.owner@test.com`: **12990**, **5 ימים**.
3. **Compare & approve** — `qa.alpha.procurement2@test.com` compares and approves cheaper quote (Supplier A).
4. **Ship** — Approved supplier marks **נשלחה**.
5. **Engineer denied** — Engineer cannot approve/send RFQ directly to suppliers.
6. **Viewer read-only** — `qa.alpha.viewer@test.com` cannot mutate RFQ/projects/members.
7. **Supplier sales rep** — `qa.supplierA.sales1@test.com` can quote; cannot manage users.
8. **Supplier viewer** — `qa.supplierA.viewer@test.com` cannot quote or manage.
9. **Uninvited supplier** — `qa.supplierC.owner@test.com` must not see Alpha RFQ when not invited.
10. **Cross-org isolation** — Beta users (`qa.beta.*`) must not see Alpha data.
11. **No access** — `qa.noaccess@test.com` sees no-permission screen; logout works.
12. **Pending** — `qa.pending@test.com` blocked from app entry.
13. **Owner admin** — `qa.alpha.owner@test.com` can manage members/invitations per role rules.

---

## Tooling

```bash
cd tools/admin
node manual_qa_inspect.js
node manual_qa_reset.js backup
node manual_qa_reset.js cleanup --dry-run
node manual_qa_reset.js cleanup --execute   # after review
node manual_qa_reset.js seed
node manual_qa_reset.js verify
```

Backups: `tools/admin/backups/manual_qa_reset_<timestamp>/` (gitignored)
