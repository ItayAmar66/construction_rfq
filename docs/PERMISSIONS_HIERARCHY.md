# Permission Hierarchy Model

## Overview

Construction RFQ uses a layered permission model:

1. **Platform** — `platformAdmin` (מנהל מערכת) — system owner only
2. **Company** — contractor/supplier org roles via `Membership`
3. **Project** — per-project team via `ProjectAssignment` (planned)

**מנהל מערכת ≠ מנהל חברה**

## Hierarchy Trees

### Platform (מנהל מערכת)

```
מנהל מערכת
  ├── חברות קבלן
  ├── ספקים
  ├── משתמשים
  ├── פרויקטים
  ├── בקשות / הצעות / הזמנות
  └── הגדרות ואבטחה
```

### Contractor Company

```
חברת קבלן
  └── מנהל חברה
        ├── מנהל רכש → רכש
        ├── מנהל פרויקט → מהנדס, צוות אתר
        ├── חשבונות
        └── צפייה בלבד
```

### Project Team

```
פרויקט
  ├── מנהל פרויקט
  ├── מהנדסים
  ├── רכש משויך
  └── צופים
```

Company role = **what** the user can do.  
Project assignment = **where** they can do it.

### Supplier Company

```
חברת ספק
  └── מנהל ספק
        ├── מנהל מכירות → נציג מכירות
        ├── מנהל תפעול → תפעול
        ├── חשבונות
        └── צפייה בלבד
```

## Role Capabilities (summary)

| Role | Key capabilities |
|------|------------------|
| מנהל חברה | users, projects, permissions, approve quotes, costs |
| רכש | create RFQs, send to suppliers, approve/reject quotes |
| מהנדס | material lists, drafts, submit to procurement |
| מנהל ספק | team, all quotes/orders |
| מנהל מכירות | quotes, sales reps |
| נציג מכירות | respond, submit quotes |
| תפעול | fulfilled orders, shipped/delivered |

## Sprint 79 — Real Membership Reads + Safe Role Foundation

### What is now real (Sprint 79)

- `OrganizationRepository.watchMembershipsForOrg(orgId)` reads from
  Firestore `organizations/{orgId}/memberships/{uid}` in production.
  Demo mode uses `MockStore` (unchanged).
- `OrganizationRepository.watchMembershipsForUser(uid)` uses a
  Firestore `collectionGroup` query in production.
- `orgMembershipsProvider(orgId)` Riverpod provider streams org members.
- Contractor screen **משתמשים והרשאות** tab shows real member rows with
  role badge, status, and enabled edit button for `canManageUsers`.
- Supplier screen **משתמשים והרשאות** tab shows real supplier team rows.
- `OrganizationRepository.updateMemberRole` enforces client-side guardrails
  in all modes (demo + production):
  - Cannot assign `platformAdmin` from company management.
  - Cannot self-promote to owner role.
  - Cannot assign a role from the wrong org type.
- `RoleChangeDialog` — role selection sheet with description + warning banner.
- `ProjectAssignmentRepository` — stream-ready model for project-level
  assignments (read-only, returns empty in demo).
- `projectAssignmentsProvider(projectId)` Riverpod provider.
- Project workspace `צוות והרשאות בפרויקט` shows empty state with
  disabled assign/edit buttons.
- Role labels updated: `contractorCompanyOwner` → **מנהל חברה**,
  `supplierOwner` → **מנהל ספק**, viewer → **צפייה בלבד**.

### Sprint 80 — Secure Membership Role Writes

#### Enforced in Firestore rules (`organizations/{orgId}/memberships/{uid}`)

- **Read:** own doc, active org members, or `platformAdmin`.
- **Create:** `platformAdmin` only; cannot self-create as owner/manager.
- **Update:** `platformAdmin` or org owner (`contractorCompanyOwner` /
  `supplierOwner`) with constraints:
  - Cannot update own membership (`memberUid != uid()`).
  - Only `roles`, `updatedAt`, `updatedByUid` may change.
  - `orgId` and `orgType` must be preserved.
  - `platformAdmin` role cannot be assigned.
  - Role must match org type (contractor vs supplier lists).
  - Non-`platformAdmin` cannot demote `organizations.ownerUid` from owner role.
- **Delete:** `platformAdmin` only.

#### Enforced client-side only (repository + dialog)

- Last-owner guard when multiple owners exist in org (counts members before write).
- Self-change blocked before any write attempt.
- Hebrew error mapping for Firestore `permission-denied` and known guardrails.

#### Sprint 82 — Invite links + email foundation + audit

- Join route: `/invite/{inviteId}` with Hebrew landing states.
- Copy-link fallback when no email provider (`DevInviteDeliveryService`).
- `deliveryStatus` on invitations: pending / sent / failed / copied / accepted.
- Audit events in `auditEvents` — see [AUDIT_EVENTS.md](AUDIT_EVENTS.md).
- Email production setup: [INVITATION_EMAILS.md](INVITATION_EMAILS.md).

#### Still requires Cloud Function / transaction later

- Counting all owners atomically at write time (race if two demotions concurrent).
- Server-side audit (`appendAuditEvent`) and `sendInvitationEmail`.
- Signed invite token (replace id-in-URL for production).

#### Deploy steps (rules changed — not auto-deployed)

```bash
firebase deploy --only firestore:rules
```

Verify with emulator before production:

```bash
firebase emulators:exec --only firestore "flutter test test/firestore_rules_security_test.dart"
```

### Sprint 81 — Invitations + Project Assignment Editing

#### Invitations (`invitations/{inviteId}`)

- Company/supplier manager creates invite via **הוסף משתמש** dialog.
- No email sending yet — invite stored as **pending** in Firestore/demo store.
- Pending invites shown under **הזמנות ממתינות**.
- Logged-in user with matching email sees **יש לך הזמנה להצטרף לחברה** banner.
- Accept creates `organizations/{orgId}/memberships/{uid}` and marks invite **accepted**.
- Manager can cancel pending invites.

#### Project assignments (`projects/{projectId}/assignments/{uid}`)

- Project workspace **צוות והרשאות בפרויקט** shows real assignment rows.
- Manager/project owner can **שייך משתמש לפרויקט** from company members.
- Roles: מנהל פרויקט, מהנדס, רכש משויך, צופה.
- Edit role and remove from project supported.
- Team count chip shown when assignments exist.

#### Firestore rules (Sprint 81 — deploy required)

```bash
firebase deploy --only firestore:rules
```

- Invitations: manager create, invited user accept, email immutable.
- Assignments: manager/owner/projectManager manage; engineer cannot assign.

### What is still NOT done

- Email sending for invitations (Cloud Function / SendGrid).
- Atomic last-owner protection across concurrent writes.
- Audit events (`auditEvents` collection).
- Full org migration / membership backfill.

### Firestore rules

Sprint 80 adds membership write rules. **Deploy required before production role edits are safe.**

- `updateMemberRole` in production calls `memberRef.update(...)` —
  rules now enforce actor permissions server-side.
- Deploy with `firebase deploy --only firestore:rules` after review.

## Read-only Now

Sprint 78 ships **read-only hierarchy UX**:

- Tree widgets show who manages whom
- Permission matrix cards explain capabilities
- Edit buttons disabled: "עריכת הרשאות בקרוב"
- No fake users when memberships empty
- Legacy `userType` fallback still works
- Firestore rules **unchanged**

## Next Phases

1. Firestore rules hardening for membership writes
2. Invite users / create membership flow
3. Project assignment UI (editing)
4. Audit events
5. Last-owner server-side guard

## QA Checklist

- **Contractor** → ניהול חברה → עץ חברה shows hierarchy + matrix
- **Contractor** → ניהול חברה → משתמשים והרשאות: empty state or real member rows
- **Manager** (contractorCompanyOwner) → edit role icon visible, dialog opens
- **Engineer** → no edit icon; read-only notice shown
- **Manager changes engineer → procurement**: snackbar "ההרשאה עודכנה"
- **Self-promotion attempt**: dialog shows error "לא ניתן לשדרג את עצמך"
- **platformAdmin assignment attempt**: error "לא ניתן להקצות תפקיד מנהל מערכת"
- **Supplier** → ניהול ספק → משתמשים והרשאות: empty state or real rows
- **Supplier owner** → edit role icon visible
- **Sales rep** → no edit; read-only notice
- **Project workspace** → צוות והרשאות בפרויקט: empty state + disabled buttons
- **Admin** → platform hierarchy card visible

## Code References

- Presets: `lib/utils/enterprise_hierarchy_presets.dart`
- Models: `lib/models/enterprise/hierarchy_node.dart`
- Widgets: `lib/widgets/permissions/`
- Role labels + descriptions: `lib/utils/enterprise_role_labels.dart`
- Org repo: `lib/repositories/organization_repository.dart`
- Assignment repo: `lib/repositories/project_assignment_repository.dart`
- Providers: `lib/providers/enterprise_providers.dart`
- Permission matrix: `EnterprisePermissionService`
