# Catalog admin management plan

Safe future catalog editing — **no client mutation UI in MVP**.

## Scope

| Capability | Channel | Permission |
|------------|---------|------------|
| Add variant | Admin SDK / import CLI | `catalogAdmin` |
| Edit display name, SKU, category | Admin tool | `catalogAdmin` |
| Deactivate variant (soft) | `isActive: false` | `catalogAdmin` |
| Image URL update | Admin metadata | `catalogAdmin` |
| Bulk import | `tools/catalog_import/` emulator gate | Ops only |

## Safety controls

1. **No in-app Firestore writes** to catalog collections (rules enforce read-only)
2. **Approval flow:** staging import → emulator gate → prod import with tag
3. **Audit log:** record who/when/what for each variant change (future `catalogAudit` collection)
4. **Rollback:** restore snapshot from pre-import export
5. **Permissions:** `canManageCatalog` role helper (Phase 55) gates future admin UI

## UI foundation (future)

- Read-only ops dashboard (`/dev/catalog-ops`) — exists in debug
- Edit UI only after admin auth + server-side validation
- Never expose batch delete in mobile client

## Non-goals

- Customer/supplier catalog mutation
- Production import from this sprint
