# Notifications foundation

MVP uses **NoOpRfqNotificationService** only — no push/email provider.

## Events

| Event | Trigger (future hook) |
|-------|----------------------|
| `rfqSent` | After `submitQuoteRequest` |
| `supplierQuoteReceived` | After `submitSupplierQuote` |
| `quoteApproved` | After `approveCustomerQuote` |
| `orderShipped` | After `markSupplierOrderShipped` |

## Integration path

1. Implement `RfqNotificationService` with FCM / email / webhook
2. Register in Riverpod provider
3. Call from `QuoteService` after successful writes
4. Keep no-op as default for demo/offline

## Payload

See `RfqNotificationPayload` — includes `requestId`, optional `quoteId`, actor IDs, title/body for localization layer.
