# Family Finance Backend API

All endpoints use JSON unless an upload is sent directly to object storage. Protected endpoints require `Authorization: Bearer <accessToken>`. Access tokens expire after 15 minutes; refresh tokens rotate and expire after 30 days. Store both tokens only in the mobile platform's secure storage.

## Authentication

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/auth/login` | Sign in; returns access and refresh tokens |
| POST | `/auth/refresh` | Rotate the refresh token and issue a new access token |
| POST | `/auth/logout` | Revoke a refresh token |
| GET | `/auth/me` | Return the current user and role profile |

Refresh and logout request body: `{ "refreshToken": "..." }`.

## Family and members

| Method | Path | Access |
| --- | --- | --- |
| GET | `/families` | Admin; latest 100 families |
| GET | `/families/me` | Parent or child in their own family |
| POST | `/families` | Admin; body `{ "name": "..." }` |
| POST | `/families/:familyId/parents` | Admin; body `name`, `email`, `password` |
| POST | `/families/:familyId/children` | Admin; body `name`, `email`, `password`; creates the child's wallet |

Family members only receive names and wallet summaries for other members; email and password hashes are not returned.

## Transactions and finance

| Method | Path | Access and behavior |
| --- | --- | --- |
| GET | `/categories` | Authenticated; active expense categories |
| GET | `/transfers` | Parent sees transfers they sent; child sees transfers addressed to them |
| POST | `/transfers` | Parent creates a pending transfer to a child in their family |
| PATCH | `/transfers/:id/confirm` | The addressed child confirms receipt; confirmed amount becomes wallet income |
| PATCH | `/transfers/:id/reject` | The addressed child reports that the money has not arrived; optional body `{ "reason": "..." }` |
| PATCH | `/transfers/:id/cancel` | The sending parent cancels a pending transfer |
| GET | `/expenses` | Parent sees family expenses; child sees their own |
| POST | `/expenses` | Child records an expense; rejected when available balance is insufficient |
| PATCH | `/expenses/:id/void` | Parent voids an active expense with a required reason |
| GET | `/history?page=1&limit=50` | Combined family or child history; page 1–100, limit 1–100 |
| GET | `/reports/overview` | Lifetime totals, category totals, and parent child balances |
| GET | `/reports/monthly?year=2026&month=11` | UTC calendar month totals and category breakdown |
| GET | `/notifications` | Current user's notifications |
| PATCH | `/notifications/:id/read` | Mark the current user's notification as read |

Currency is fixed to Indonesian rupiah (`IDR`). Amounts are sent as whole-rupiah strings without decimals, for example `{ "amount": "25000" }`. Responses include `currency: "IDR"`; format them as Rupiah in the client. A new transfer does not affect the wallet balance while pending or rejected; it counts as income only after the child confirms receipt.

Example parent transfer body: `{ "childId": "<child UUID>", "amount": "25000", "note": "Uang mingguan" }`.

Example child expense body: `{ "categoryId": "<category UUID>", "amount": "12000", "description": "Makan siang", "spentAt": "2026-11-02T05:00:00.000Z" }`. `spentAt` is optional and defaults to the current server time.

## Deferred: photo/document uploads

Photo uploads are disabled in the active NestJS module setup for now. No S3-compatible storage configuration is needed for the current backend flow. The existing attachment schema and additive migration are retained; do not use the attachment endpoints until this feature is re-enabled and storage is configured.

Required environment variable names for the backend: `DATABASE_URL`, `JWT_SECRET`, `ADMIN_NAME`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` for the initial admin seed. `PORT` is optional and defaults to 3000.

## Local development

Apply the pending migrations to a development database before using the reject endpoint and IDR whole-rupiah storage. Prisma applies all pending migration folders in order:

```cmd
npm run prisma:migrate:dev
npm run prisma:generate
npm run start:dev
```

Do not use `migrate dev` against production. Production deployment should generate and review a migration artifact first, then apply it through the deployment migration workflow.
