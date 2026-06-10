# Platform Admin Bootstrap

## Goal

Grant Itay (or other trusted operators) **platform admin** without letting clients self-elevate via Firestore profile fields.

## Authoritative sources (in order)

1. **Firebase Auth custom claim** `platformAdmin: true` (recommended)
2. **Server-side bootstrap allowlist** (UID/email) used only in trusted tooling — never writable from the Flutter client

The app reads claims via `AuthSession.customClaims` and `PlatformAdmin.fromCustomClaims()`.

## Assigning Itay as platform admin

### Option A — Admin SDK / Cloud Function (production)

```javascript
const admin = require('firebase-admin');
await admin.auth().setCustomUserClaims('<ITAY_UID>', { platformAdmin: true });
```

User must sign out and sign in again (or refresh ID token) for claims to apply.

### Option B — Firebase CLI + script

Use a one-off Node script with a service account — same `setCustomUserClaims` call.

## What platform admin can do (app layer)

- `EffectivePermissions` grants all `Permission` values when `platformAdmin` claim is true
- Admin Console route `/admin` is visible only with the claim (or future membership `platformAdmin` role after migration)

## What clients must NOT do

- Do not store `platformAdmin` on `users/{uid}` as an authoritative field
- Do not allow registration or profile update to set admin flags
- Firestore rules include `isPlatformAdmin()` helper reading `request.auth.token.platformAdmin` only

## Legacy compatibility

Until organization migration completes, normal `userType` customers/suppliers keep legacy permission fallbacks in `EffectivePermissions`.
