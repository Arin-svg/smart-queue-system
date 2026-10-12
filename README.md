# Smart Queue System

Flutter application and Laravel API for UMPSA PKU Pekan, implemented against
`PSM1_CB23094_V2.pdf`, section 3.3 and Figures 3.14–3.34. The original figures
were extracted from the PDF and inspected visually, including dialogs and profiles.

## Implemented workflows

- **Patient (green):** scan the clinic QR, choose department and visit reason, register,
  view queue and history, book available appointment slots, check in or cancel,
  read notifications, update phone number, and change password.
- **Registration staff (cyan):** monitor and filter queues, assist existing patient
  accounts with walk-in registration, verify identity, approve priority, assign or
  reassign doctor/room, requeue skipped patients, generate/print/download clinic QR.
- **Doctor (orange):** view assigned patients in approved order, call next patient,
  start/complete consultation, skip or mark a called patient absent.
- **Administrator (purple):** dashboard totals, user search/role filters, create/edit/
  enable/disable users, departments and rooms; queue settings; audit logs; date and
  department reports with a column chart and PDF export.
- Account menu, sign out, password recovery, role checks, request errors, loading
  indicators, confirmation dialogs, and empty states.

Screens use real API data. Demonstration records exist only in test fixtures.

## Run locally

Start MySQL in XAMPP. In `backend/`:

```powershell
php artisan migrate
php artisan serve --host=127.0.0.1 --port=8000
```

Use a separate terminal for scheduled reminders and waiting-time notifications:

```powershell
php artisan schedule:work
```

From the project root:

```powershell
flutter run -d chrome
```

For Android: `flutter run`. The emulator API defaults to `http://10.0.2.2:8000/api`;
web/desktop defaults to `http://127.0.0.1:8000/api`. Physical devices require a
reachable API host supplied with `--dart-define=API_BASE_URL=...`.

Create real accounts with `php artisan sqs:create-user`, or through an administrator
account. No shared default password or demonstration accounts are installed.

## Predictions and notifications

Waiting-time prediction uses a local nearest-neighbour regression over completed
consultations in the same department, with doctor, visit type and consultation hour
as features. A chronological holdout compares error against a simple average.
Until there are at least ten valid samples, or when the model performs worse than
that baseline, the UI identifies an average-based estimate instead of claiming AI.
The wait calculation accounts for approved priority and doctor/room capacity.

Priority suggestions learn from staff-approved cases with similar visit reasons,
department, waiting time and visit type. The model abstains without five comparable
cases or a majority agreement. Only a staff action with a recorded reason changes
priority. These models require evaluation with representative clinic data before
operational reliance; automated tests do not establish clinical effectiveness.

Foreground queue and notification screens refresh every ten seconds and can be
refreshed manually. Appointment reminders and prediction updates require the Laravel
scheduler. Device push notifications while the application is closed are not configured.

## Password recovery

Configure a real mail transport in `backend/.env` (`MAIL_MAILER`, SMTP host, port,
credentials and sender), and set `APP_URL` to an address the recipient can reach.
The log mailer intentionally returns an unavailable message rather than claiming to
send email. Reset links expire, are single use, and revoke existing login tokens.
Tokens in Flutter remain in memory; restarting the app requires signing in again.

## Validation

```powershell
flutter analyze
flutter test
flutter build web
```

In `backend/`: `php artisan test`. Backend tests force SQLite `:memory:` and never
reset the imported MySQL database. Tests cover role isolation, QR expiry, duplicate
queues, status transitions, approved queue order, room assignment, appointment
capacity, reminders, reports, password resets, and model abstention.

Flutter tests exercise all four roles at 390px and 1200px and verify confirmation
before mutation. Local visual renders can be generated with
`flutter test --dart-define=RENDER_SQS=true`; screenshots are written to
`.tmp/screenshots/`. For readable rendered text, put a test Roboto font at
`.tmp/Roboto-Regular.ttf`. This font is only for screenshot tests.

Physical-camera scanning, native print/share dialogs, SMTP delivery and background
hosting/scheduler operation still require environment/device acceptance checks.
See [implementation traceability](docs/implementation-reference.md) and
[backend setup](backend/README.md).



test punya password: Test1234!
drAmi amiamiami