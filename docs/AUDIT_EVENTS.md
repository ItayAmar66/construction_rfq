# Audit events

## Collection

`auditEvents/{eventId}` — client-written audit trail for permissions and project actions.

## Model fields

| Field | Description |
|-------|-------------|
| `actorUid` | User performing action |
| `actorEmail`, `actorName` | Optional display |
| `orgId`, `orgType` | Organization scope |
| `projectId` | Project scope (optional) |
| `entityType` | `invitation`, `membership`, `projectAssignment`, `project`, … |
| `entityId` | Target record id |
| `action` | e.g. `invitationCreated`, `roleChanged`, `projectAssigned` |
| `summaryHebrew` | Human-readable Hebrew line |
| `metadata` | Small string map (no secrets) |
| `createdAt` | Timestamp |

## Recorded actions (Sprint 82)

- Invitation created / cancelled / accepted
- Membership role changed
- Project assignment created / updated / removed
- Project completed
- Project deletion requested / cancelled

Audit writes are **fire-and-forget** — failures log in debug and do not block the main action.

## UI visibility

- **Admin console** — recent platform audit
- **חברה → היסטוריית פעולות** — org-scoped events
- **Project workspace** — compact recent project events

Empty state: *עדיין אין פעולות להצגה*

## Security / limitations

**Client-side audit is not tamper-proof.** For production-grade audit:

- Add server-side `appendAuditEvent` Cloud Function
- Verify actor and action server-side before write
- Consider append-only storage with no client create

Firestore rules (Sprint 82):

- Create: signed-in, `actorUid == auth.uid`
- Read: platform admin, org managers (org events), project owner/manager/assignee (project events)

## Deploy

After rule changes:

```bash
firebase deploy --only firestore:rules --project construction-rfq-itay-20-2eee0
```

Composite index may be required: `auditEvents` — `orgId` + `createdAt` desc, `projectId` + `createdAt` desc.

## Future work

- Server-side audit for RFQ sent, quote approved/rejected, order shipped
- Atomic last-owner protection on role changes
