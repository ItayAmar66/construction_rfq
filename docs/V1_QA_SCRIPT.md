# V1 QA Script — Construction RFQ

Run against **demo mode** or **Firebase staging**. Do not run production catalog import during QA.

## Roles to test

| Role | How | Focus |
|------|-----|-------|
| Legacy contractor | `commercialCustomer` register/demo | Projects, RFQ, approve |
| Legacy supplier | `commercialSupplier` register/demo | Incoming, quote, ship |
| Platform admin | Custom claim `platformAdmin: true` only | Admin console |
| Enterprise roles | Membership docs (future) | Permission gates |

## Contractor

1. Home → **פרויקטים** empty → **צור פרויקט ראשון**
2. Create project (name, location, city)
3. **בקשה חדשה** from project card → RFQ preselects project
4. Catalog: **סל** white button, +/- on rows, images quiet on failure
5. Submit RFQ → customer list shows **פרויקט: name · location**
6. Compare/approve quote
7. Profile → **ניהול חברה** (legacy customer sees it)

## Engineer / procurement (when membership exists)

- Engineer: **שלח לאישור רכש** only
- Procurement: **שלח לספקים**, approve quotes

## Supplier

1. Incoming: targeted/open RFQs, project chip
2. Closed tender: **המכרז נסגר**, not tappable
3. Submit quote → status **ממתין להחלטת לקוח**
4. After customer approve → order in **הזמנות**
5. Mark shipped (legacy supplier OK)
6. Sent quotes: **זכית** / **לא נבחר** / **נשלח/סופק**
7. Profile → **ניהול ספק** (legacy supplier owner)

## Admin (Itay)

1. Set custom claim via Admin SDK (see `docs/ADMIN_BOOTSTRAP.md`)
2. Profile → **ניהול מערכת**
3. Panels load (read-only shells OK)

## Security smoke

- Normal user cannot set `platformAdmin` on profile
- Supplier cannot read `projects/` collection
- Supplier sees project only on RFQ snapshot

## Permission hierarchy (Sprint 78)

1. Contractor → **ניהול חברה** → tab **עץ חברה** shows tree + matrix
2. Tab **משתמשים והרשאות** — empty team state or current user; edit disabled
3. Project workspace → **צוות והרשאות בפרויקט** section; **הזמנה חדשה** still works
4. Supplier → **ניהול ספק** → **עץ ספק** with מנהל ספק / מכירות / תפעול
5. Admin → **מנהל מערכת** card; text **מנהל מערכת ≠ מנהל חברה**
6. Engineer without manage permission → blocked from company screen

See `docs/PERMISSIONS_HIERARCHY.md`.

## Pass criteria

- `flutter analyze` — no errors
- `flutter test` — green
- No cart/checkout wording (except **סל** on catalog)
- Hebrew RTL throughout
