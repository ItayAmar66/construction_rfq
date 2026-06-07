# Security notes

Release security posture for Construction RFQ (Phase 64A+).

## Firestore rules — what is protected

### Catalog (read-only clients)

- `catalogCategories`, `catalogProducts`, `catalogVariants`, `catalogMeta`, legacy `products` — **read** if signed in; **write: false** for all clients.
- Import uses REST + ADC tooling, not client SDK.

### Users (`users/{uid}`)

- **Create:** `userType` must be one of four valid types; `verified` must be `false`; `uid` and `email` must match auth.
- **Update:** `userType`, `verified`, `uid`, `email` are **immutable** from client. Only `name`, `fullName`, `phone`, `city`, `notes`, `updatedAt` may change.
- **Delete:** denied.
- **Admin / elevated roles:** not supported via client writes.

### Quote requests (`quoteRequests`)

- **Create:** `customerId == uid()`; status must be valid enum; embedded `items[]` list size and scalar fields validated.
- **Update:** customer ownership; embedded `items` changes validated at list level.
- Cross-user writes denied.

### Supplier quotes (`supplierQuotes`)

- **Create:** `supplierId == uid()`; `customerId` must match linked request; prices non-negative; status enum valid.
- **Read:** supplier owner or customer linked via request.
- Legacy top-level item collections: create with ownership checks; update/delete blocked.

## Remaining limitations

| Area | Limitation | Mitigation |
|------|------------|------------|
| Embedded `items[]` | Rules cannot iterate/deep-validate each line | App-layer validation (`SupplierCatalogMatchValidation`, submit guards) |
| Manual items | Rules check scalars only, not business truth | Client + review UX; future server validation |
| Status transitions | Invalid status strings blocked; graph not fully enforced in rules | App lifecycle services; approval service |
| Supplier `stats` / `verified` | Not client-writable after signup | Future Admin SDK / Cloud Functions |
| Tenant isolation | Single-project; no org-level RBAC in rules | Future custom claims |

## Future: custom claims & Cloud Functions

Recommended path for enterprise:

1. **Custom claims** — `role`, `tenantId`, `admin` set only via Admin SDK.
2. **Cloud Functions** — validate RFQ submit, quote approve, status transitions, notification dispatch.
3. **Rules** — `request.auth.token.role` / `tenantId` for multi-tenant reads.

Do not weaken existing rules when adding claims; extend with new match blocks.

## Manual item validation limits

- Rules allow `productName`, `category`, `unitType`, `quantity` on embedded items.
- No server-side check that manual names match catalog SKUs.
- App requires quantity > 0 and non-empty name before submit.

## Approval / status transition limits

- Rules block unknown status strings and foreign ownership.
- Ordered → shipped transitions rely on supplier/customer app flows + quote service.
- Double-approve guarded in `ApprovalService` (app layer).

## Testing

- `test/firestore_rules_security_test.dart` — static rules coverage.
- Do not deploy rule changes without running tests + staging verification.
