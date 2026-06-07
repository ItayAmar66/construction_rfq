# Auth & roles — release scope

## Current enforcement

| Layer | What is enforced |
|-------|------------------|
| Firestore rules | `userType` / `verified` immutability; ownership on RFQ/quotes; catalog read-only |
| App UI | Customer vs supplier routes via `userType`; demo login debug-only |
| Helpers | `RolePermissions`, supplier targeting visibility (soft) |

## What UI does NOT provide

- No admin console in production UI.
- No client-side role escalation or user verification toggle.
- `/dev/catalog-ops` is **debug-only** route — not a product admin feature.

## Roadmap (document only)

1. Firebase Auth **custom claims** for `admin`, `tenantId`.
2. **Cloud Functions** to set claims and audit privileged actions.
3. Firestore rules extended with `request.auth.token` checks.
4. Optional admin web app (separate from mobile client).

See `SECURITY_NOTES.md` for rule details.
