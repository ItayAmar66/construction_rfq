# Company Demo QA Checklist

Manual checklist before showing Construction RFQ to construction companies.  
Use **demo login** (no Firebase required) unless production Firebase is explicitly configured.

## Before the demo

- [ ] `flutter analyze` — no errors
- [ ] `flutter test` — all green
- [ ] App runs in demo mode (login shows demo buttons)
- [ ] Log in as **קבלן לדוגמה** — dashboard shows demo banner + scenario panel
- [ ] Pre-seeded scenarios visible: **השוואת הצעות** and **הזמנה מאושרת**
- [ ] No `tools/catalog_import/out/*` artifacts committed or deployed

## Customer flow

| Step | Action | Verify |
|------|--------|--------|
| 1 | Dashboard → **טיוטת דרישה** | Summary bar, catalog/manual sections |
| 2 | **בחר מהקטלוג** | Selector loads categories, search works, no full-catalog load |
| 3 | Add catalog line | SKU, category, quantity visible |
| 4 | **הוסף פריט ידני** | Manual section works, notes optional |
| 5 | Review section | Targeting summary chip (open / category / invited) |
| 6 | **שליחה לספקים** | Confirmation screen, request appears in **הבקשות שלי** |

## Supplier flow

| Step | Action | Verify |
|------|--------|--------|
| 1 | Log out → **התחבר כספק לדוגמה** | Demo banner on supplier dashboard |
| 2 | **בקשות נכנסות** | Incoming RFQ visible, relevance chip if applicable |
| 3 | Open request → submit quote | Exact match on catalog line, manual line priced |
| 4 | Optional: submit **alternative** on catalog line | Alternative note required, badge shown |

## Catalog flow

- [ ] Category chips filter results; selected category banner + **נקה קטגוריה** works
- [ ] Search debounces; empty state shows helpful hint
- [ ] Pagination **טען עוד** still works (no full catalog load)
- [ ] Procurement wording only (no cart/shop language)

## Quote compare

| Step | Action | Verify |
|------|--------|--------|
| 1 | Customer → scenario **השוואת הצעות** or open compare from request | Matrix on wide screen, cards on mobile |
| 2 | Check matrix | Totals row, exact/alternative/missing indicators, lowest highlight |
| 3 | Timeline | sent → quoted → approved → shipped steps consistent |
| 4 | Approve quote | Alternative warning if applicable; order created |

## Approved / shipped order

- [ ] Scenario **הזמנה מאושרת** → **הזמנות פעילות** or order list
- [ ] Status shows approved / shipped path
- [ ] Supplier can mark shipped in demo (if testing full loop)

## Security / data (Firebase environments only)

- [ ] Catalog collections read-only for clients
- [ ] No client writes to `catalogVariants`, `catalogProducts`, etc.
- [ ] Quote/request access unchanged from prior sprints
- [ ] Embedded catalog snapshot fields on quote items persist

## After demo

- [ ] Reset demo: log out and log in again (scenarios re-seed idempotently)
- [ ] Note any blockers for follow-up (do not deploy import tools to production)

## Automated regression (run locally)

```bash
flutter analyze
flutter test
```

Key suites: `enterprise_demo_scenario_test`, `request_timeline_test`, `firestore_rules_security_test`, `rfq_architecture_guardrails_test`, `catalog_rfq_lifecycle_test`.
