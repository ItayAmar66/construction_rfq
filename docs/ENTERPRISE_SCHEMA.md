# Enterprise Schema & Migration

## Collections

### `users/{uid}` (profile only)

- Existing fields unchanged
- Planned: `primaryOrgId`, `legacyUserType` (mirror during migration)

### `organizations/{orgId}`

- `type`: `platform` | `contractor` | `supplier`
- `name`, `ownerUid`, `status`, `createdAt`, `updatedAt`

### `organizations/{orgId}/memberships/{uid}` (or `memberships/{orgId_uid}`)

- `uid`, `orgId`, `orgType`, `roles[]`, `status`, `projectIds[]`, `createdBy`, timestamps

### `projects/{projectId}`

- `orgId`, `name`, `siteName`, `city`, `status`, `managerUids[]`, `createdBy`, timestamps

### `projectAssignments/{projectId_uid}`

- `projectId`, `orgId`, `uid`, `role`, `createdAt`

### `supplierDirectory/{uid}` (public read)

- `displayName`, `orgId`, `city`, `categoryIds`, `serviceAreas`, `active`
- Backfilled from supplier users — contractors query this instead of listing all `users`

### `quoteRequests/{id}` — new optional fields

| Field | Purpose |
|-------|---------|
| `contractorOrgId` | Owning contractor org |
| `projectId`, `projectName`, `siteName` | Project context |
| `createdByUid`, `preparedByUid`, `submittedByUid`, `approvedByUid` | Workflow actors |
| `invitedSupplierOrgIds` | Org-level targeting |
| `status` | Adds `ממתין לאישור רכש` / `pendingApproval` |

### `supplierQuotes/{id}` — planned fields

- `supplierOrgId`, `createdByUid`, `submittedByUid`, `opsUpdatedByUid`
- `decisionStatus`: `pending` | `won` | `lost` | `rejected`

## Migration plan (non-destructive)

1. Create contractor org per existing `commercialCustomer` / `privateCustomer`
2. Create supplier org per supplier user
3. Owner membership for each existing user
4. Backfill `quoteRequests` with `contractorOrgId`, `createdByUid`
5. Backfill `supplierQuotes` with `supplierOrgId`, `createdByUid`
6. Populate `supplierDirectory` from supplier profiles (public fields only)
7. Keep `customerId` / `supplierId` fallback in rules and queries until cutover

## Current sprint status

| Area | Status |
|------|--------|
| Dart domain models | Implemented |
| Permission service + legacy fallback | Implemented |
| Project association on RFQ | Implemented (optional) |
| Draft / pending approval | Implemented (app + rules allow create) |
| Membership Firestore reads | Stub (empty provider) |
| Org admin UI | Shell only |
| Full rules org membership | Scaffolded helpers; legacy UID rules remain |

## Deploy later

- Firestore rules changes (`supplierDirectory`, `pendingApproval`, `isPlatformAdmin`)
- Custom claims for platform admin
- `supplierDirectory` backfill job
- Organization/membership collections population
