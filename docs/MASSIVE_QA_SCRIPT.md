# Massive QA Script

Run in **demo mode** first, then staging Firebase with real catalog.

## 1. Auth & profile

1. Register new contractor — lands on **ממתין לאישור מנהל מערכת**, cannot create project/RFQ
2. Platform admin approves as manager — user reaches home with active org
3. Login wrong password — Hebrew error, not stack trace
4. Login with `?redirect=/invite/...` — lands on invite after auth
5. Logout and re-login

## 2. Engineer → procurement → supplier RFQ

1. Manager/procurement invites engineer
2. Engineer: project → catalog → RFQ draft → **שלח לאישור רכש** (no supplier picker)
3. Procurement home: **בקשות ממתינות לאישור** → **מאושר**
4. **המשך לשליחת בקשה לספקים** → suppliers receive RFQ
5. Rejected request cannot be sent until resubmitted (if implemented)

## 3. Customer RFQ → order (procurement path)

1. Home → create project (active membership required)
2. Open project workspace → **הזמנה חדשה**
3. Catalog: search, category filter, add items, draft count updates
4. RFQ draft: manual + catalog lines, project context preserved
5. Procurement sends to suppliers (targeted or open)
6. **הבקשות שלי** — request visible with project chip
7. Wait/receive supplier quote → **השוואת הצעות**
8. Approve one quote — second approval blocked
9. **הזמנות פעילות** — order appears
10. After supplier marks shipped — status updates

## 4. Supplier flow

1. Login supplier — incoming RFQs visible, cards clickable
2. Submit quote — validation on empty price
3. Duplicate quote blocked
4. After customer approval — **הזמנות לביצוע**
5. Mark shipped — appears in history

## 5. Invitations & permissions

1. Manager → **הוסף משתמש** → copy link (all contractor launch roles)
2. Procurement → invite **מהנדס** or **צפייה בלבד** only
3. Open link signed out → Hebrew prompt
4. Login with invited email → accept → `accountStatus` active + membership
5. Wrong email blocked; accepted invite cannot re-accept
6. Engineer cannot manage company roles or invite users
7. Supplier owner invites **רכש ספק**; supplier procurement cannot manage users

## 5. Admin

1. Platform admin → **ניהול מערכת**
2. Counts, users, projects, RFQs, audit, invitations panels
3. Non-admin cannot access console

## 6. Edge cases

- Empty projects, empty catalog search, no incoming RFQs
- Permission denied shows Hebrew message (not `[cloud_firestore/...]`)
- Completed / deletion-pending project blocks new order
- RTL layout on narrow width (375px) — login, dashboard, compare

## Pass criteria

- No crashes; no raw exception strings in UI
- Hebrew RTL throughout
- Real catalog only in production (no fake marketplace seed)
