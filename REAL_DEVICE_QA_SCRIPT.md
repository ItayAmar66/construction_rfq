# Real device / web QA script

Release QA for Construction RFQ. Run against **Firebase staging/production** when catalog import is available; use **debug+demo mode** only for offline/demo scenarios.

## Device matrix

| Platform | Form factor | Priority |
|----------|-------------|----------|
| Chrome | Desktop 1280×800+ | P0 |
| Chrome | Mobile emulation 390×844 | P0 |
| iOS Safari | Phone | P1 |
| Android Chrome | Phone | P1 |
| iPad / tablet | Landscape + portrait | P2 |

Record: OS version, browser, screen size, build SHA, Firebase project.

---

## Setup

1. `flutter run -d chrome` or install release build on device
2. Confirm Firebase project (not demo) for catalog tests
3. Note start time + network (Wi‑Fi / 4G / throttled)

---

## A. Customer — RFQ draft

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| A1 | Login customer | Dashboard, no demo banner in release | Demo banner in prod |
| A2 | Open **טיוטת בקשה** | RFQ wording, no cart/checkout | עגלה / checkout copy |
| A3 | **בחר מהקטלוג** → variant | Line in catalog section + SKU | Hang, fake products |
| A4 | **הוסף פריט ידני** | Manual line with qty | Blocked |
| A5 | Review → **שליחה לספקים** | Confirmation, request in list | Submit error |

## B. Supplier — quote

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| B1 | Login supplier | Incoming requests visible | Wrong role |
| B2 | Open request | Customer + materials summary | Raw request ID only |
| B3 | Exact catalog line quote | Match badge, totals | Missing exact path |
| B4 | Manual line quote | Included in total | Skipped |
| B5 | Submit | Sent quotes list updated | Validation error |

## C. Alternative quote

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| C1 | Alternative line + note | Submit succeeds | Silent accept without note |
| C2 | Customer compare | Alternative badge + warning | Missing labels |

## D. Compare & approve

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| D1 | Compare quotes | Matrix/cards, supplier names | Empty |
| D2 | Approve one quote | Active order, status update | Double approve |

## E. Fulfillment

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| E1 | Customer active orders | Material summary + status + date | ID-only title |
| E2 | Supplier marks shipped | Customer sees shipped | Stuck |

---

## F. Catalog (production)

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| F1 | Open catalog selector | First 50 browse OR partial banner | Demo/fake catalog |
| F2 | **כל הקטגוריות** → search category | All categories reachable | Only 40 chips |
| F3 | Category + Hebrew search | Text not ignored | Category-only browse |
| F4 | SKU search (`fx-100`) | SKU prefix results | Wrong routing |
| F5 | Load more | Appends next page | Resets list |
| F6 | Empty / partial catalog | Hebrew blocked state + retry + manual hint | Fake products |
| F7 | Permission denied (wrong rules) | Hebrew error, retry | Raw exception |

## G. RTL / layout

- [ ] Hebrew text direction RTL on all primary screens
- [ ] AppBar back chevron correct side
- [ ] Chips, lists, forms not clipped on mobile width
- [ ] Compare matrix scrolls horizontally on narrow screens
- [ ] Long material names truncate gracefully

## H. Network / resilience

| # | Scenario | Expected |
|---|----------|----------|
| H1 | Slow 3G (DevTools throttle) | Loading states, no crash |
| H2 | Offline mid-browse | Error + retry |
| H3 | Failed RFQ submit | Hebrew error, draft preserved |
| H4 | Permission denied | Actionable message, no admin jargon |

## I. Role / tenant checks

| # | Check | Expected |
|---|-------|----------|
| I1 | Customer cannot write supplier quote | Blocked by rules/app |
| I2 | Supplier cannot edit customer request | Blocked |
| I3 | User cannot escalate `userType` / `verified` | Rules reject |
| I4 | Catalog collections client write | Always denied |

---

## Evidence checklist

For each failed step record:

- [ ] Step ID (e.g. F3)
- [ ] Device + browser + viewport
- [ ] Screenshot / screen recording
- [ ] Console / `flutter logs` excerpt
- [ ] Firebase project + user role
- [ ] Catalog import state (variant count if known)

---

## Pass criteria

- A + B + D + F1–F5 pass on Chrome desktop
- No cart/checkout wording in user-facing UI
- Manual + catalog items work end-to-end
- Partial catalog shows banner, not fake data
- RTL checklist passes on mobile emulation

See also: `TOMORROW_SMOKE_TEST.md` for post-import smoke.
