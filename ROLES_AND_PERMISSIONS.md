# Roles and permissions

Foundation helpers in `lib/utils/role_permissions.dart` — **not enforced in Firestore rules yet**.

| Role | Maps from | canCreateRequest | canApproveQuote | canManageCatalog |
|------|-----------|------------------|-----------------|------------------|
| customerAdmin | commercialCustomer | ✓ | ✓ | — |
| purchasing | privateCustomer | ✓ | ✓ | — |
| engineer | (future) | ✓ | — | — |
| supplier | supplier types | — | — | — |
| admin | (future flag) | ✓ | ✓ | ✓ |

Login flow unchanged. Use helpers in UI guards before destructive actions.
