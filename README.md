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
  reassign doctor/room, requeue skipped patients, view/print/download clinic QR.
- **Doctor (orange):** view assigned patients in approved order, call next patient,
  start/complete consultation, skip or mark a called patient absent.
- **Administrator (purple):** dashboard totals, user search/role filters, create/edit/
  enable/disable users, departments and rooms; queue settings; audit logs; date and
  department reports with a column chart and PDF export.
- Account menu, sign out, password recovery, role checks, request errors, loading
  indicators, confirmation dialogs, and empty states.

Screens use real API data. Demonstration records exist only in test fixtures.

The clinic QR code is shared and does not expire. The page loads the saved code
automatically and has no refresh controls. Only an administrator can generate the first
code or replace it, through Home → Queue Settings → Manage Clinic QR Code.
Replacing it invalidates old printed copies; print and distribute the new
code afterward. The upgrade preserves the existing QR token and clears its former
expiry timestamp.

Appointments start as **Pending** and reserve the selected slot. Staff review them
under **Verify → Appointments Awaiting Verification → Verify Appointment** before
they become **Confirmed**. Only confirmed appointments receive reminders and allow
check-in. The upgrade returns upcoming app-created, auto-confirmed bookings without
a staff verification or check-in to pending, keeping their reserved slots.

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

### Ask SQS chat companion

Patient pages include a draggable Ask SQS bubble. Home's AI Chat shortcut opens
the same conversation. Minimize to continue using the app; history remains in
memory until sign-out, app restart, or Clear conversation. English and Bahasa
Melayu replies are available from Chat options. This is a read-only assistant:
it guides users to pages but cannot book/cancel appointments or change priority.

Set `GROQ_API_KEY` locally in `backend/.env` and choose a model available to your
Groq account using `GROQ_MODEL` (default `openai/gpt-oss-20b`). Run
`php artisan config:clear` and restart Laravel after changes. Never put the key
in Flutter or commit it. Without a key the chat displays a setup error rather
than pretending to generate AI replies. Provider quotas/billing may apply.

The authenticated `/api/ai/chat` endpoint is patient-only and limited to 10 requests
per minute. It sends the current message, up to 10 recent conversation messages,
and an allowlisted summary of that patient's active queue and next appointment to
Groq. Names, emails, phone numbers, IDs and reasons for visits are not
included automatically. Users see a disclosure before messaging. Messages are
not stored in the application database. Review provider data terms and clinic
approval before using real patient data. Answers may be wrong and do not replace
staff or medical assessment. Test coverage uses mocked Groq responses.

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

## Import a student batch

Administrators can open **Users → Import spreadsheet**, save the CSV template,
and choose an Excel `.xlsx` (one data sheet) or UTF-8 CSV file. Use headers
`name,email,user_identifier,phone_no,role,status`; the first three are required.
Blank role/status default to `patient`/`active`. Format IDs and phone numbers as
Text in Excel to preserve leading zeros. Imports support up to 500 users and 2 MB.

Preview shows invalid rows, duplicate rows and existing accounts before confirmation.
Only ready rows are created; existing accounts are never updated. Each new account
uses the normal temporary-password email flow. Keep the import screen open while
it processes users. Stop takes effect after the current user. Save the result CSV
to track skipped or failed rows. If a request times out, inspect Users before
retrying; upload again for a fresh duplicate check. SMTP provider sending limits
still apply, and SMTP acceptance does not guarantee inbox delivery.

## Password recovery

Admin Add User generates a random temporary password and immediately sends it to
the user's email. Admin forms do not accept passwords. Users can change their
password in their profile after signing in. Creation requires a working mail
transport; if sending fails, the new account is rolled back so creation can be retried.
Editing an existing user does not change their password or send another email.

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
reset the imported MySQL database. Tests cover role isolation, static QR persistence and replacement, duplicate
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


### Android device notifications

Firebase Messaging is configured for Android. On a rebuilt app, allow notification
permission and sign in to register the device. New clinic alerts and queue changes
appear in the notification tray; tapping a queue alert opens My Queue. Android
may suppress delivery after a force-stop until the app is opened again.

The server service-account file belongs at
`backend/storage/app/firebase-service-account.json` (Git-ignored). Never bundle
this private file in Flutter. Apply migrations with `php artisan migrate`.
Keep the backend running and run `php artisan schedule:work` in another terminal
inside `backend`. This generates reminders every minute and sends pending push
notifications every ten seconds. `php artisan sqs:push` performs one delivery pass.
The device receives new alerts after registration; existing inbox history is not
replayed. Delivery is tied to the authenticated session and stops after sign-out,
revocation, account deactivation, or session expiry. Failed delivery is retried on
the next pass. FCM acceptance is not proof that a device displayed a notification.


test punya password: Test1234!
drAmi amiamiami