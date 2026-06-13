# Known Limitations — Closed Beta

## Email invitations

- Production email sending requires Cloud Function + provider env vars (see `docs/INVITATION_EMAILS.md`)
- Until configured: **copy invite link** is the delivery method
- Invite URLs use invitation id (dev); signed tokens recommended for GA

## Audit trail

- Events written from client (`auditEvents` collection)
- Not tamper-proof — server-side `appendAuditEvent` recommended for production compliance
- Commerce audit wired for RFQ sent, quote submit/approve/reject, order shipped, project lifecycle

## Permissions

- Last owner protection is **client-side only** — concurrent demotions not atomically prevented
- Legacy users without org membership use profile-based permissions (unchanged)
- Membership collectionGroup query requires `uid` field on documents (fixed for new accepts; backfill legacy if any)

## Catalog

- Images may fail without Storage CORS — fallback UI shown, app not blocked
- Do not run production catalog import during QA sprints

## Admin

- Console is read-only overview — no in-app user/role management
- Requires `platformAdmin` custom claim for full Firestore read access

## Not in scope for closed beta

- Atomic last-owner Cloud Function
- Production-grade email provider
- Server-side audit
- Payment / billing integration
