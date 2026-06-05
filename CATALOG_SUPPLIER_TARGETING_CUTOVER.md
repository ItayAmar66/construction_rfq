# Supplier targeting — cutover plan

## Current foundation

- `QuoteRequest.invitedSupplierIds` — optional invite-only list
- `SupplierTargetingHelpers` — service area, category overlap, soft labels
- Broad visibility default; hard-hide only when invite list non-empty
- Customer review shows targeting summary before send

## Data model (no change required)

| Field | Location | Purpose |
|-------|----------|---------|
| `invitedSupplierIds` | QuoteRequest | Explicit invite-only mode |
| `supplierCategoryIds` | AppUser | Supplier capabilities |
| `serviceAreas` | AppUser | Region/city coverage |
| `categoryId` on lines | QuoteRequestItem | Request category signals |

## Migration strategy

1. **Phase A — Soft (current):** Labels + relevance chips; all open RFQs visible unless invited list set.
2. **Phase B — Opt-in strict:** Customer can enable "רק ספקים רלוונטיים" on send (sets flag, not hard cutover globally).
3. **Phase C — Supplier-side filter:** `shouldShowToSupplier` adds category+area filter when request flag `targetRelevantOnly` true.
4. **Phase D — Invited tenders:** Use `invitedSupplierIds` for closed RFQs / preferred suppliers.

## Fallback rules

- Empty `invitedSupplierIds` → broad visibility (never break legacy RFQs)
- Empty supplier categories → treat as generalist (visible, label "פתוח לכל הספקים")
- Manual-only RFQs → open to all unless invited list exists

## Rollout

| Step | Action | Risk |
|------|--------|------|
| 1 | Ship customer targeting summary (done) | Low |
| 2 | Add request flag `targetRelevantOnly` (future) | Medium — needs Firestore field + rules |
| 3 | Enable filter in `watchIncomingRequestsForSupplier` behind flag | Medium |
| 4 | Migrate demo + pilot customers | Low with flag default false |

## Do not (yet)

- Hard-hide all non-matching suppliers globally
- Change Firestore rules without index review
- Remove broad fallback for manual items
