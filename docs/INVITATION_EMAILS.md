# Invitation emails

## Current flow

1. Manager creates invitation in **חברה → משתמשים והרשאות → הוסף משתמש**.
2. Document stored at `invitations/{inviteId}` with `status: pending`, `deliveryStatus: pending`.
3. Join link: `/invite/{inviteId}` (dev uses invitation id; production should move to signed token).
4. Invitee opens link → login/register with invited email → **הצטרף לחברה**.
5. Accept creates `organizations/{orgId}/memberships/{uid}` and marks invitation accepted.

## Copy-link fallback (local / demo)

When no email provider is configured (`DevInviteDeliveryService`):

- UI shows **העתק קישור הזמנה** as primary action.
- Message: *כרגע ניתן להעתיק קישור הזמנה. שליחת מייל אוטומטית תחובר בהמשך.*
- `deliveryStatus` updates to `copied` after delivery attempt.

## Production email setup

**Do not commit secrets.** Configure provider in Cloud Function environment only.

### Recommended Cloud Function: `sendInvitationEmail`

- Callable HTTPS function, requires Firebase Auth.
- Verify caller can manage org invites (`canManageOrgMemberships`).
- Load invitation, build Hebrew email (see `InvitationEmailCopy` in app).
- Send via provider (SendGrid, Mailgun, SES, etc.) using env vars:
  - `EMAIL_PROVIDER_API_KEY`
  - `EMAIL_FROM_ADDRESS`
  - `APP_BASE_URL` (for absolute invite links)
- Update `deliveryStatus` to `sent` or `failed`.

Scaffold: see `tools/functions/README.md`.

### Deploy (when ready)

```bash
firebase deploy --only functions:sendInvitationEmail --project construction-rfq-itay-20-2eee0
firebase deploy --only firestore:rules --project construction-rfq-itay-20-2eee0
```

## Security notes

- Invitation id in URL is acceptable for dev; use hashed/signed token for production.
- Firestore rules restrict accept to matching email and `acceptedByUid == auth.uid`.
- Immutable fields on update: `orgId`, `email`, `role` (except platform admin).

## QA checklist

- [ ] Create invite → success dialog + copy link
- [ ] Open `/invite/{id}` signed out → Hebrew prompt to login
- [ ] Wrong email → blocked message
- [ ] Matching email → join succeeds
- [ ] Cancel invite → status בוטל
- [ ] After rules deploy: production accept/cancel/resend
