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

## Read-only Now

Sprint 78 ships **read-only hierarchy UX**:

- Tree widgets show who manages whom
- Permission matrix cards explain capabilities
- Edit buttons disabled: "עריכת הרשאות בקרוב"
- No fake users when memberships empty
- Legacy `userType` fallback still works
- Firestore rules **unchanged**

## Next Phases

1. Real memberships read (Firestore)
2. Role edit service + invite flow
3. Project assignment UI
4. Firestore rules hardening
5. Audit events

## QA Checklist

- **Contractor** → ניהול חברה → עץ חברה shows hierarchy + matrix
- **Supplier** → ניהול ספק → עץ ספק shows hierarchy
- **Project workspace** → צוות והרשאות בפרויקט section visible
- **Admin** → מנהל מערכת card + "≠ מנהל חברה" notice
- **Engineer** → cannot open company management (no permission)
- **Manager** → sees trees; edit buttons disabled

## Code References

- Presets: `lib/utils/enterprise_hierarchy_presets.dart`
- Models: `lib/models/enterprise/hierarchy_node.dart`
- Widgets: `lib/widgets/permissions/`
- Permission matrix: `EnterprisePermissionService`
