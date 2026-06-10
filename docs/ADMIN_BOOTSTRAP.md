# Platform Admin Bootstrap

## Goal

Grant **Itay Amar** (`itayamar206@gmail.com`) full platform control without client-editable profile fields.

## Authoritative security (Firestore + permissions)

- **Firebase Auth custom claim:** `platformAdmin: true`
- Firestore rules: `isPlatformAdmin()` reads `request.auth.token.platformAdmin == true` only
- `EffectivePermissions` grants all capabilities only from the custom claim — **not** from profile email

## UI bootstrap (temporary)

Until the claim is set, the app shows **ניהול מערכת** for `itayamar206@gmail.com` via `PlatformAdmin.bootstrapEmails` (UI visibility only). Firestore admin access still requires the claim after rules deploy.

## Set custom claim for Itay

**Project ID:** `construction-rfq-itay-20-2eee0`  
**Email:** `itayamar206@gmail.com`

### Option A — repo script (recommended)

```bash
cd tools/admin
npm install
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
node set_platform_admin.js itayamar206@gmail.com
```

Service account needs **Firebase Authentication Admin** (or equivalent) on project `construction-rfq-itay-20-2eee0`.

With Application Default Credentials:

```bash
gcloud auth application-default login
cd tools/admin && npm install
node set_platform_admin.js itayamar206@gmail.com
```

### Option B — Admin SDK one-liner

```javascript
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'construction-rfq-itay-20-2eee0' });
const user = await admin.auth().getUserByEmail('itayamar206@gmail.com');
await admin.auth().setCustomUserClaims(user.uid, { platformAdmin: true });
```

### After setting the claim

1. User signs **out** and **in** again (refresh ID token).
2. Deploy Firestore rules if not already deployed: `firebase deploy --only firestore:rules`

## What platform admin can do

- Read/manage all `projects/{projectId}` (Firestore rules)
- All app permissions via `EffectivePermissions` when claim is present
- Admin Console `/admin` — **ניהול מערכת**

## What clients must NOT do

- Do not store `platformAdmin` on `users/{uid}` as authoritative
- Registration/profile update cannot set admin flags
- Normal users cannot self-promote via Firestore writes

## Legacy compatibility

Customers/suppliers without memberships keep `userType`-based permission fallback in `EffectivePermissions`.
