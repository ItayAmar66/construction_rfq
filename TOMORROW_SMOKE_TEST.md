# Post-import smoke test (~15 min)

Run after catalog import resume session. **Firebase production/staging**, real accounts.

## Preconditions

- [ ] Light verify passed (`--verify-production-light`)
- [ ] Variant count increased vs last checkpoint
- [ ] `flutter test` green on deployed app build

## Checks

| # | Step | Pass |
|---|------|------|
| 1 | Customer login | ☐ |
| 2 | Catalog selector opens (no demo products) | ☐ |
| 3 | Browse loads ~50 items + load more | ☐ |
| 4 | Hebrew search returns results | ☐ |
| 5 | Category picker → filter category | ☐ |
| 6 | Add catalog item to **טיוטת בקשה** | ☐ |
| 7 | Add manual item | ☐ |
| 8 | Submit RFQ to suppliers | ☐ |
| 9 | Supplier login → incoming request | ☐ |
| 10 | Submit exact quote | ☐ |
| 11 | Customer compare + approve | ☐ |
| 12 | Active order shows material summary | ☐ |

## If partial catalog

- [ ] Partial banner visible (not blocking if variants exist)
- [ ] Search still works on imported subset
- [ ] Manual item fallback works

## Record

- Build SHA, variant count, pass/fail per step, screenshots of failures.
