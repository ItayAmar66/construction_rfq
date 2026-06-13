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

### What is still NOT done

- Invite users / create memberships flow.
- Project assignment editing (disabled button placeholder).
- Full org migration / membership backfill.
- Audit events (`auditEvents` collection).
- Firestore security rules for membership role updates
  (write path in production protected by client guardrails only;
  Firestore rules must be hardened before production launch).
- Server-side last-owner check (client-side only today).

### Firestore rules

Membership write rules **not yet deployed**. Until rules are hardened:
- `updateMemberRole` in production calls `memberRef.update(...)` —
  requires Firestore rules to allow the actor.
- Keep write disabled in production until rules are reviewed.

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
