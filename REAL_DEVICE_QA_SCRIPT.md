# Real device / web QA script

Run in **demo mode** unless Firebase staging is explicitly configured.

## Setup

1. Install build on device or run `flutter run -d chrome`
2. Confirm demo login buttons visible
3. Note start time

---

## A. Customer — create RFQ

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| A1 | Login **קבלן לדוגמה** | Dashboard + demo banner + scenarios | Blank dashboard, crash |
| A2 | Open **טיוטת דרישה** | Empty or draft state with CTA | Cart/shop wording |
| A3 | **בחר מהקטלוג** → pick variant | Line in catalog section with SKU | Full catalog hang |
| A4 | **הוסף פריט ידני** | Manual section with qty | Manual block missing |
| A5 | Review → targeting chip visible | Category/open copy | Missing review |
| A6 | **שליחה לספקים** | Confirmation + request in list | Submit error |

## B. Supplier — quote

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| B1 | Logout → **ספק לדוגמה** | Supplier dashboard | Wrong role |
| B2 | **בקשות נכנסות** | Active RFQ or seeded compare request | Empty with no seed |
| B3 | Open request → price catalog line **exact** | Match controls, totals | Missing exact toggle |
| B4 | Price manual line | Included in total | Line skipped |
| B5 | Submit quote | Success snackbar, sent quotes list | Validation error |

## C. Supplier — alternative (optional)

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| C1 | Login **גימור פרו** or use seeded alt quote | Alternative badge on compare | Missing alt flag |
| C2 | Alternative requires note | Block or warn without note | Silent accept |

## D. Customer — compare & approve

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| D1 | Scenario **השוואת הצעות** | Matrix (wide) + cards | Empty compare |
| D2 | Timeline shows sent→quoted | Audit steps | Broken timeline |
| D3 | Approve one quote | Order created, others not selected | Double approve |

## E. Fulfillment & history

| # | Action | Expected | Failure sign |
|---|--------|----------|--------------|
| E1 | Open **הזמנה מאושרת** scenario | Shipped status | Wrong status |
| E2 | Supplier marks shipped (if testing live flow) | Customer sees shipped | Stuck on ordered |

---

## Pass criteria

- All A + B + D steps pass
- No cart/checkout wording
- Manual items work end-to-end
- Demo scenarios load without Firebase

## Log defects with

- Step ID, device, screenshot, console output
