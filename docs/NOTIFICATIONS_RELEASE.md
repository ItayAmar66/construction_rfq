# Notifications — release scope

## Current state (MVP)

- `RfqNotificationService` defines lifecycle events: RFQ sent, quote received, approved, shipped.
- **Default implementation:** `NoOpRfqNotificationService` — records payloads in tests only; **no email, SMS, or push** in production.
- Hooks are called from quote/approval flows but delivery is intentionally discarded.

## Product claims

**Do not claim** push/email notifications in release notes or sales demos until a provider is wired.

## Future integration (not in this sprint)

1. Implement `RfqNotificationService` with FCM / email provider.
2. Keep existing payload shape (`RfqNotificationPayload`).
3. Dispatch from Cloud Functions for trusted server-side triggers.

## QA

- `test/rfq_notification_service_test.dart` verifies payload shape on lifecycle events.
