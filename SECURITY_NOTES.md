# Security notes

## User roles (`users/{uid}`)

- Clients may choose `userType` **once** at registration (customer vs supplier variants).
- After creation, `userType`, `verified`, `uid`, and `email` are **immutable** from the client.
- Profile updates are limited to `name`, `fullName`, `phone`, `city`, `notes`, `updatedAt`.
- **Admin / elevated roles** are not supported via Firestore client writes. Use Firebase Auth custom claims + Cloud Functions (or Admin SDK) for future admin tooling.

## RFQ / quotes

- Primary item data lives in embedded `items[]` on `quoteRequests` and `supplierQuotes`.
- Rules validate required fields, status enums, ownership, list sizes, and non-negative prices.
- Per-item deep validation inside large embedded arrays is intentionally limited (Firestore rules cannot iterate lists). The app layer still validates catalog match shapes.
- Legacy top-level `quoteRequestItems` / `supplierQuoteItems` creates require ownership + basic field validation; updates remain blocked.

## Catalog

- Production catalog collections remain **read-only** for clients (`allow write: if false`).
- Catalog import uses REST + ADC tooling, not client SDK writes.

## Known limitations

- Embedded array item content is not fully schema-validated in rules (size + scalar checks only).
- Supplier public `stats` on user docs are not client-writable after registration, but can be set at signup; trusted stats require server-side updates later.
- Status transition graphs (e.g. ordered → sent only via app flows) rely partly on app logic; rules block invalid status strings and cross-user writes.
