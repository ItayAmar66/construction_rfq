# Codex Audit 1: Product + QA

## Status

Audit only complete. Workspace reset to `origin/main`, no production import run, final `git status --short` was clean before writing this document.

## Readiness score 1-10

6.5/10. Demo-ready for an RFQ walkthrough, not yet ready as a real construction RFQ product.

## Critical blockers

- No real device/web QA evidence yet; script exists but was not executed.
- Production readiness still admits partial catalog/search, supplier targeting, notifications, analytics, deploy/import, and role enforcement.
- Public polish gaps: default Flutter README, demo-mode surfaces, internal request IDs, generic errors.

## UX/product issues

- Mostly RFQ/procurement, but legacy `/cart`, `CartScreen`, and old catalog/product paths still carry e-commerce architecture.
- Customer active orders and request lists expose "בקשה abc123..." instead of meaningful project/material summaries.
- Some error states are generic; catalog errors can expose technical/debug copy.
- Demo scenario panel makes dashboard feel staged unless strictly demo-only.
- Supplier history/sent quotes are thin compared with compare/approval flow.
- CTAs are generally clear: "בחר מהקטלוג", "הוסף פריט ידני", "שליחה לספקים", "הגש הצעה", "אשר הצעה".

## QA gaps

- No mobile/tablet/desktop matrix.
- No visual RTL/layout checklist.
- No slow network, offline, Firestore permission, empty catalog, missing index, or failed submit cases.
- No role/tenant access QA.
- No notification/analytics verification.
- No staging import/rollback drill.
- No explicit screenshots or acceptance evidence per step.

## Screens ready

- Customer dashboard, with caveat demo surfaces.
- RFQ/material request builder.
- Catalog selector.
- Quote compare / approval.
- Supplier dashboard.
- Supplier incoming requests.
- Supplier quote response.

## Screens needing fixes

- Customer active orders.
- Customer request history/list.
- Supplier sent quotes/history.
- Supplier order detail polish.
- Product catalog / legacy cart surfaces.
- Login/README/demo entry polish for real product presentation.

## Top 10 recommended fixes

1. Rename/route away from cart semantics to RFQ draft/request builder.
2. Replace internal request IDs with project/material summaries.
3. Remove or gate demo panels for non-demo presentation.
4. Strengthen active orders with supplier, delivery, approved quote, shipment timeline.
5. Improve sent quotes/history with customer/request context and actions.
6. Replace generic errors with actionable Hebrew copy.
7. Hide debug catalog hints from product-facing builds.
8. Expand `REAL_DEVICE_QA_SCRIPT.md` into device/browser/RTL/error/security matrix.
9. Update README from Flutter starter to product/runbook.
10. Execute real-device QA and record pass/fail evidence before demo.
