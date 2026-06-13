# Cloud Functions scaffold — invitation email

This folder documents the recommended production email function. **No secrets in repo.**

## Function: `sendInvitationEmail`

Callable from Flutter via `CloudFunctionInviteDeliveryService` (when configured).

### Responsibilities

1. Require `context.auth`.
2. Load `invitations/{inviteId}`; verify caller manages `orgId`.
3. Build Hebrew subject/body (match `InvitationEmailCopy` in app).
4. Send email via provider using runtime env vars.
5. Update `deliveryStatus` to `sent` or `failed`.

### Example env (`.env` on deploy host — not committed)

```
EMAIL_PROVIDER=sendgrid
EMAIL_PROVIDER_API_KEY=...
EMAIL_FROM_ADDRESS=noreply@example.com
APP_BASE_URL=https://your-app.web.app
```

### Deploy

```bash
cd functions   # when implemented
npm install
firebase deploy --only functions:sendInvitationEmail --project construction-rfq-itay-20-2eee0
```

Until implemented, the app uses `DevInviteDeliveryService` (copy link only).
