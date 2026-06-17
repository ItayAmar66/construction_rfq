# Closed Beta — Manual Live Smoke Checklist

**Live URL:** https://construction-rfq-itay-20-2eee0.web.app/?v=final

**Tip (Flutter Web):** If automation is needed, open DevTools console and run:
`document.querySelector('flt-semantics-placeholder')?.click()` to enable accessibility.

---

## Flow A — Engineer → Procurement → Suppliers → Approve → Ship

### 1. Engineer — create request

- [ ] **Pass** / [ ] **Fail**
- Login: `qa.contractor.big.engineer@test.com` / `Qa123456!`
- Open catalog or assigned project
- Add 2–3 catalog products
- Submit: **שלח לאישור רכש**
- Expected: status **ממתין לאישור רכש**, success copy **נשלחה לאישור רכש**
- Record `requestId`: _______________

### 2. Procurement — approve and send to QA suppliers

- [ ] **Pass** / [ ] **Fail**
- Login: `qa.contractor.big.procurement@test.com` / `Qa123456!`
- Find request from step 1
- Click **מאושר** → **המשך לשליחת בקשה לספקים**
- Search/select: **QA ספק גדול בע"מ** and **QA ספק קטן**
- Send
- Expected: status **נשלח**, both QA suppliers visible, no permission-denied

### 3. Big supplier — submit quote

- [ ] **Pass** / [ ] **Fail**
- Login: `qa.supplier.big.owner@test.com` / `Qa123456!`
- Open incoming RFQ
- Quote: price **12345**, delivery **7 ימים**
- Expected: quote saved, footer total updates, success state
- Record `quoteId`: _______________

### 4. Small supplier — submit quote

- [ ] **Pass** / [ ] **Fail**
- Login: `qa.supplier.small.owner@test.com` / `Qa123456!`
- Open same RFQ
- Quote: price **12990**, delivery **5 ימים**
- Expected: quote saved, footer total updates, success state
- Record `quoteId`: _______________

### 5. Procurement — compare and approve

- [ ] **Pass** / [ ] **Fail**
- Login: `qa.contractor.big.procurement@test.com` / `Qa123456!`
- Open compare quotes for the request
- Confirm both quotes visible
- Approve cheaper/better quote — **first approval succeeds**
- Try approving second quote — **blocked**
- Expected: `approvedQuoteId` set, order/status updated

### 6. Approved supplier — mark shipped

- [ ] **Pass** / [ ] **Fail**
- Login as the **approved** supplier account
- Open **הזמנות לביצוע**
- Find the order → click **סמן נשלחה**
- Expected: order visible before shipping, mark succeeds, status **נשלחה**

---

## Flow B — No-permission logout

- [ ] **Pass** / [ ] **Fail**
- Use a user that lands on no-permission screen (or trigger if available)
- Click **התנתקות**
- Expected: returns to login screen (no grey screen)

---

## Sign-off

| Check | Result |
|-------|--------|
| Full Flow A | Pass / Fail |
| Logout | Pass / Fail |
| Console permission-denied errors | None / List |
| Tester | |
| Date | |
