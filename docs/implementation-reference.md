# Document traceability and visual verification

Reference: **PSM1_CB23094_V2.pdf**, section 3.3 requirements and section 3.6 prototypes.
Printed page numbers are five lower than PDF page indices (one-based).
Original embedded images were extracted locally and inspected, rather than inferring
the layouts only from `reference_v2.txt`.

## Current database reference

The user-provided `smart_queue_system (1).sql` export is the current database
reference. It was compared with Laravel's configured MySQL database,
`smart_queue_system`: all 14 tables have matching column names, and the export
records all three migrations as applied, matching the live database.

`database/smart_queue_system.sql` is the original eight-domain-table setup script
for a new installation. The current export also contains migration tracking,
access tokens, password reset tokens, clinic settings, audit logs and priority
training samples. These are support tables used by the implemented application.
The eight core entities from the document remain intact.

No import, table recreation, migration rerun or data update was needed for this
comparison. At the time of inspection, the live database contained four departments
and no rooms, queues or appointments. Consultation rooms and doctor assignments
must be configured through the administrator interface before staff can assign
patients. The SQL export remains outside the repository; account data is not copied
into documentation or test fixtures.

## Prototype mapping

| Figures | Implemented interface | Main files |
| --- | --- | --- |
| 3.14 | Login and password recovery | `login_page.dart`, `forgot_password.dart`, `widgets/auth_layout.dart` |
| 3.15 | Top-right account menu and sign out | `session_page.dart` |
| 3.16 | QR scan → department → reason → queue | `registration_page.dart` |
| 3.17 | Queue ticket, status, wait, progress, quick actions | `queue_page.dart` |
| 3.18 | Department, optional doctor, available date/time booking | `appointment_page.dart` |
| 3.19 | Unread/read notification list | `notification_page.dart` |
| 3.20, 3.25, 3.28, 3.34 | Account information and password change | `profile_page.dart` |
| 3.21 | Staff totals, filters and queue cards | `monitor_page.dart` |
| 3.22 | Identity verification and empty state | `verify_page.dart` |
| 3.23 | Prediction panels, priority review, doctor/room assignment | `assign_page.dart`, `widgets/prediction_panels.dart` |
| 3.24 | Shared static clinic QR, automatic loading, print, PDF download | `qr_code_page.dart` |
| 3.26 | Doctor status totals, next patient and waiting list | `call_patient_page.dart` |
| 3.27 | Start/complete consultation and skipped/absent actions | `consultation_page.dart` |
| 3.29 | Admin totals and management navigation | `dashboard_page.dart` |
| 3.30 | User search, role filter, create/edit/disable | `users_page.dart` |
| 3.31 | Department create/edit/enable/disable | `departments_page.dart` |
| 3.32 | Room name/number, department and assigned doctor | `rooms_page.dart` |
| 3.33 | Date/department report, distribution chart and export | `reports_page.dart`, `widgets/department_chart.dart` |

Paths above are relative to `lib/pages/`. Role colors follow the actual figures:
patient green, staff cyan, doctor orange, administrator purple. The application
preserves the pale background, white rounded cards, heart/SQS header, avatar menu,
and each role's bottom navigation. Content scrolls on smaller devices and is
width-constrained on desktop. Native Flutter controls and real data can change exact
text wrapping and dimensions; this is not a claim of pixel-identical reproduction.

## Requirements beyond the pictured screens

- Appointments remain pending until staff explicitly verify them from the Verify
  tab. Pending bookings reserve capacity; confirmation enables check-in and reminders.
  Upcoming bookings auto-confirmed by the application are returned to pending if
  they have no staff verification or check-in.
- Per the user's updated requirement, the clinic QR code does not expire and stays
  identical across staff sessions until an administrator replaces it. The QR page
  loads automatically with no refresh controls. Administrators manage the code from Home → Queue Settings → Manage
  Clinic QR Code. The upgrade keeps the existing token and clears its old expiry;
  replacing a code invalidates old copies.
- Settings and audit logs appear below the administrator dashboard totals.
- Staff can register an existing patient account without requiring that patient to
  operate the scanner. Account creation stays under administrator permissions.
- Queue priority requires an explicit staff decision and reason; the model never
  changes ordering itself.
- Backend transactions enforce one active queue, available appointment capacity,
  doctor/room/department compatibility, role isolation and consultation transitions.
- Queue changes notify the patient. The scheduler generates appointment reminders
  and changed waiting-time estimates. Foreground refresh is every ten seconds.
- Patient identity, email and role are read-only. Patients may edit their phone
  number. Staff, doctor and administrator profile details are read-only.

## Deliberate handling of prototype examples

- Names, counts, queue numbers and timestamps come from the database. Examples
  printed in the PDF are not inserted as real accounts, visits or notifications.
- Actual booking slots follow configured clinic hours and capacity rather than the
  arbitrary example time in Figure 3.18.
- Figure 3.23 depicts a doctor/room combination that is not consistent. The actual
  assignment form only permits a room belonging to the selected doctor/department.
- Skip/absent is available after a patient is called, before consultation begins,
  following the explicit alternative flow in Table 3.7.
- The user-management text specifies disabling accounts. The prototype's trash
  icon is not implemented as destructive deletion of related clinic records.
- Example prescription-pickup notifications do not create a pharmacy/EMR integration;
  those systems are excluded by section 3.3.3.
- Average fallback estimates are identified as averages; AI labels appear only when
  the data-driven model can run. Priority recommendations abstain without comparable
  staff-reviewed cases. No accuracy or medical validation is claimed.

## Verification and remaining acceptance checks

Automated Flutter tests render all role tabs at 390×844 and 1200×844, and test
authentication, confirmation before verification, refresh failures and duplicate
submission handling. Rendered PNGs are in `.tmp/screenshots/` (ignored by Git).
The in-app browser was unavailable; visual QA used direct Flutter renders instead.

Backend tests use isolated in-memory SQLite and cover complete consultation flow,
permissions, patient isolation, static QR persistence and administrator-only replacement,
duplicate registration, approved queue
order, busy doctors, invalid room assignments, slot capacity, reminder deduplication,
report restrictions, password reset reuse/revocation, and prediction fallback.

Remaining environment checks: real SMTP delivery, physical-camera scanning, native
print/share dialogs, and running the API/scheduler continuously. Background device
push delivery is not configured. Representative clinic data and operational review
are required before relying on learned predictions. Database migration is additive
and was applied locally without deleting existing records.
