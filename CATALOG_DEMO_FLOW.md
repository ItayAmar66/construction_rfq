# Catalog RFQ demo flow (investor / QA)

Demo mode: log in as **customer demo** → build RFQ → submit → switch to **supplier demo** → quote → back to customer → compare → approve.

## Enterprise walkthrough (Phase 38 / 45)

Demo customer: **א.ב. בנייה בע״מ** · project **מגדלי הים החדש · אתר 12**.

On customer demo login, three pre-seeded requests load:

| Request | Status | Use |
|---------|--------|-----|
| `demo-enterprise-active` | נשלח | Fresh RFQ for supplier quoting (catalog + manual) |
| `demo-enterprise-compare` | התקבלו הצעות | Exact vs alternative compare matrix |
| `demo-enterprise-fulfilled` | בדרך | Approved + shipped order |

Suppliers: **חומרי בניין צפון** (exact), **גימור פרו אספקה** (alternative), **בלוקים וצמנט המרכז**.

## Recommended demo path (Phase 28)

| Step | Action | Highlight |
|------|--------|-------------|
| 1 | Customer dashboard → **טיוטת דרישה** | Summary bar + catalog/manual sections |
| 2 | **בחר מהקטלוג** | Premium selector cards (SKU, category, thumbnail) |
| 3 | **הוסף פריט ידני** | Manual section |
| 4 | **שליחה לספקים** | RFQ submitted |
| 5 | Supplier incoming → quote | Exact/alternative controls |
| 6 | Customer **השוואת הצעות** | Decision summary panel |
| 7 | Approve (with alternative warning if needed) | Order created |

Debug-only: `/dev/catalog-ops`, `/dev/catalog-selector` (`kDebugMode`).

Legacy browse: `/catalog` → **הוסף לבקשה** → `/cart` (route kept internally).

## Copy conventions

- **טיוטת דרישה**, **שורות בקשה**, **שליחה לספקים**, **השוואת הצעות**
- Procurement icons (`request_quote`, `inventory_2`) — no shopping cart
- Route `/cart` + `CartScreen` kept for compatibility

## Automated coverage

- `test/rfq_builder_ux_test.dart` — builder sections + selector cards
- `test/catalog_rfq_lifecycle_test.dart` — full lifecycle
- `test/quote_decision_metrics_test.dart` — compare summary
- `test/supplier_targeting_test.dart` — targeting foundation
- `test/enterprise_demo_scenario_test.dart` — pre-seeded compare + fulfilled orders

## Related docs

- `CATALOG_SELECTOR_UI.md`
- `CATALOG_SUPPLIER_MATCHING.md`
- `CATALOG_SUPPLIER_TARGETING.md`
- `QUOTE_SERVICE_REFACTOR_PLAN.md`
