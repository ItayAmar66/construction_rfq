# Massive QA Script

Run in **demo mode** first, then staging Firebase with real catalog.

## 1. Auth & profile

1. Register new contractor — profile loads, no raw Firebase errors
2. Login wrong password — Hebrew error, not stack trace
3. Login with `?redirect=/invite/...` — lands on invite after auth
4. Logout and re-login

## 2. Customer RFQ → order

1. Home → create project
2. Open project workspace → **הזמנה חדשה**
3. Catalog: search, category filter, add items, draft count updates
4. RFQ draft: manual + catalog lines, project context preserved
5. Send to suppliers (targeted or open)
6. **הבקשות שלי** — request visible with project chip
7. Wait/receive supplier quote → **השוואת הצעות**
8. Approve one quote — second approval blocked
9. **הזמנות פעילות** — order appears
10. After supplier marks shipped — status updates

## 3. Supplier flow

1. Login supplier — incoming RFQs visible, cards clickable
2. Submit quote — validation on empty price
3. Duplicate quote blocked
4. After customer approval — **הזמנות לביצוע**
5. Mark shipped — appears in history

## 4. Invitations & permissions

1. Manager → **הוסף משתמש** → copy link
2. Open link signed out → Hebrew prompt
3. Login with invited email → accept → home with membership
4. Wrong email blocked; accepted invite cannot re-accept
5. Engineer cannot manage company roles
6. Project manager can manage team (if assigned)

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
