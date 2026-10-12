# SQS Laravel API

Laravel 12 API for the Flutter application. It uses the eight existing domain tables
from `database/smart_queue_system.sql`, plus additive migrations for access tokens,
clinic settings, audit logs, password resets, room numbers and priority training data.

The supplied `smart_queue_system (1).sql` is a current export of this database,
including all three applied migrations. Its 14 tables and column names match the
configured live `smart_queue_system` database. No re-import is needed for the
current workspace. The SQL file under `database/` is the original new-installation
baseline, not a replacement for the current database export.

## Setup

Start MySQL in XAMPP, configure `.env`, then run:

```powershell
php artisan migrate
php artisan serve --host=127.0.0.1 --port=8000
```

The local migrations have been applied without dropping existing tables. On a new
machine, import the initial SQL once, then run migrations. Do not use `migrate:fresh`
or `db:wipe` on an existing clinic database.

Create a first account using `php artisan sqs:create-user`. Administrators can then
manage users, departments and room/doctor assignments through the app. The four roles
are `patient`, `staff`, `doctor`, and `administrator`.

Run `php artisan schedule:work` in a separate local terminal for appointment reminders
and waiting-time updates. Production hosting must run `php artisan schedule:run`
every minute. `php artisan sqs:notifications` performs one notification update.

Use `APP_TIMEZONE=Asia/Kuala_Lumpur` for clinic slot dates and operating hours.
`SESSION_DRIVER=file` and `CACHE_STORE=file` are suitable for local setup.

## Authentication and email

All business endpoints require `Authorization: Bearer <token>`. Tokens expire after
12 hours. Disabled accounts cannot use existing sessions. Logout revokes the current
token. Password changes revoke other sessions; password resets revoke every session.

Configure a real SMTP/mail transport and an externally reachable `APP_URL` for
password-reset emails. The default log transport does not claim delivery. The reset
form is `/reset-password/{token}?email=...`; tokens expire after 60 minutes and are
single use. Login and reset requests are rate-limited.

Never commit `.env`. HTTPS is required for deployed mobile connections and browser
camera access, except supported localhost development.

## API

| Method and path (under `/api`) | Access and purpose |
| --- | --- |
| `POST /login` | User identifier and password |
| `POST /forgot-password` | Email reset request |
| `GET /me`, `POST /logout` | Current account/session |
| `GET /workspace` | Role-scoped queues, bookings, notifications, and reference data |
| `POST /notifications/{id}/read` | Notification owner only |
| `GET /clinic/qr` | Staff/admin: read the saved clinic QR code without changing it |
| `POST /clinic/qr` | Administrator only: create or explicitly replace the non-expiring code |
| `POST /clinic/qr/validate` | Patient: validate scanned code |
| `POST /queues` | Patient with QR or staff assisting an existing patient |
| `POST /queues/{id}` | Role-checked verify/assign/priority/call/start/complete/skip/absent/requeue/cancel |
| `GET /appointments/slots` | Available slots for department/date/optional doctor |
| `POST /appointments`, `POST /appointments/{id}/cancel` | Patient bookings |
| `POST /appointments/{id}/verify` | Staff only: explicitly confirm a pending appointment |
| `POST /admin/users/{id?}` | Administrator account creation/edit/status |
| `POST /admin/departments/{id?}` | Administrator department management |
| `POST /admin/rooms/{id?}` | Administrator room/doctor management |
| `POST /admin/settings` | Opening hours, slot length/capacity, registration and fallback duration |
| `GET /reports?start=YYYY-MM-DD&end=YYYY-MM-DD&department_id=...` | Administrator report aggregates |
| `POST /profile` | Patient phone-number update |
| `POST /profile/password` | Current account password change |

Clinic QR codes remain valid until an administrator replaces them. Staff reads
and exports never rotate a code. If no code exists, GET returns a null
token and an administrator must create it. The static-QR migration clears the old
expiry timestamp while preserving the stored token and existing printed QR codes.
Replacement is serialized with registration and recorded in the audit log; the
previous token is rejected immediately after replacement.

Queue writes and booking checks run inside serialized clinic transactions to avoid
competing allocations. A patient can have only one active queue. Doctor actions
require assignment and valid transitions. Room/doctor changes and deactivation are
blocked while dependent work remains active. Existing records are not hard-deleted.

New bookings are pending and reserve capacity until cancelled or processed. Staff
verification records the staff member in the audit log and notifies the patient.
Only confirmed appointments can check in or receive appointment reminders. The
verification migration returns upcoming auto-confirmed application bookings to
pending only when a patient booking audit exists and no verification or check-in
exists. Imported, checked-in, past, cancelled and staff-confirmed records are preserved.

Workspace lists currently cap queue history at 250, appointments at 150 and
notifications/logs at 100. Administrator summary/report counts do not use these caps.

## Prediction models

`QueueIntelligence` provides nearest-neighbour consultation-duration regression with
chronological validation, and staff-labelled priority classification with abstention.
`Clinic` calculates queue-ahead counts and room capacity. `ClinicNotifications`
generates scheduled reminders and changed-wait estimates. No diagnosis/treatment data
or automatic clinical priority changes are implemented.

See the root README for sample requirements, fallbacks and deployment limitations.

## Tests

`php artisan test` forces SQLite `:memory:`. Tests never reset the imported MySQL
database. The suite covers auth, the complete queue lifecycle, role isolation,
booking capacity, static QR persistence and administrator-only replacement, reminder
deduplication, password reset and model behavior.
