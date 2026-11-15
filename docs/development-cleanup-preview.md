# SQS development-data cleanup preview

Inspected **15 November 2026**, Asia/Kuala_Lumpur, against the configured local MySQL database `smart_queue_system`. **No deletion or synthetic-data insertion has been executed.** This document proposes an explicit selection for approval; being old does not automatically make a record invalid.

## Proposed selection

Delete queues **1–8**, appointments **1–7**, and only the selected queues' dependent consultation, notification and priority-training rows. Preserve queue **9**, registered today, and all configuration/accounts. Queue 6 was completed today but originated in October; queue 7 is still assigned. Both are explicitly included in this proposal for review rather than silently treated as terminal records.

| Table | Before | Proposed deletion | Remaining |
| --- | ---: | ---: | ---: |
| queues | 9 | 8 | 1 |
| consultations | 6 | 6 | 0 |
| appointments | 7 | 7 | 0 |
| notifications | 147 | 101 | 46 |
| priority_training_samples | 1 | 1 | 0 |
| users | 48 | 0 | 48 |
| roles | 4 | 0 | 4 |
| departments | 4 | 0 | 4 |
| rooms | 4 | 0 | 4 |
| clinic_settings | 1 | 0 | 1 |
| audit_logs | 76 | 0 | 76 existing |
| personal_access_tokens | 33 | 0 | 33 |
| push_devices | 1 | 0 | 1 |
| password_reset_tokens | 1 | 0 | 1 |
| migrations | 6 | 0 | 6 |

If an approved cleanup is eventually executed, it appends **one** cleanup audit entry. All 76 existing audit entries remain. No auto-increment counter is reset, and no QR token, account status, password, room assignment or setting is changed.

The 46 retained notifications comprise **15 linked to queue 9** and **31 with no queue ID**. The latter include appointment messages, generic verification messages and a test notification. There is no appointment foreign key on notifications, so they are preserved rather than deleted by ambiguous message matching. They can be reviewed as a separate explicit selection later if desired; the prepared command does not delete unlinked notifications.

## Queue-by-queue inspection

Wait means `called_at - registered_at`, as used by existing reports. Duration means consultation `ended_at - started_at`, as used by the duration model. A dash means the relevant workflow timestamp does not exist, not a zero-minute wait.

| Queue | Number | Status | Registered | Wait, minutes | Duration | Linked notifications | Proposed treatment |
| --- | --- | --- | --- | ---: | --- | ---: | --- |
| 1 | 261012-00001 | absent | 12 Oct 23:50:34 | 9.82 | No consultation start | 6 | Delete old test visit and consultation 2 |
| 2 | 261012-00002 | completed | 12 Oct 23:54:06 | 2.65 | 5 seconds | 7 | Delete old test visit and consultation 1 |
| 3 | 261014-00003 | completed | 14 Oct 02:22:25 | 13.55 | 79 seconds | 8 | Delete old test visit and consultation 3 |
| 4 | 261015-00004 | completed | 15 Oct 00:54:31 | 20.93 | 5 seconds | 8 | Delete visit, consultation 4 and linked appointment 3 |
| 5 | 261020-00005 | completed | 20 Oct 12:13:21 | 6.68 | 44 seconds | 20 | Delete visit, consultation 5 and priority sample 1 |
| 6 | 261020-00006 | completed | 20 Oct 12:13:59 | **37,593.58** | 9 seconds | 21 | Delete old visit completed on 15 Nov, and consultation 6 |
| 7 | 261020-00007 | assigned | 20 Oct 12:14:46 | — | — | 18 | Delete stale active test visit, subject to approval |
| 8 | 261020-00008 | cancelled | 20 Oct 14:14:29 | — | — | 13 | Delete old cancelled test visit |
| 9 | 261115-00009 | verified | 15 Nov 13:36:07 | — | — | 15 | **Preserve today's visit** |

Findings:

- Queue 6 was called at **15 Nov 14:47:34** after an October registration. Its wait is approximately **26 days, 2 hours, 34 minutes**. The timestamps are chronologically ordered, but this is an unsuitable historical operational wait for a realistic synthetic-data exercise.
- Queue 7 has remained active since 20 October. It remains in application workload queries and can block that patient's new registration. The application does not automatically expire it.
- Five completed consultations last only 5–79 seconds. These look like rapid development workflow exercises; they should not be represented as realistic clinical duration observations.
- Queues 1–4 were registered outside the current configured 08:00–17:00 hours. This is a plausibility finding, not proof the configuration was the same on those dates. Walk-in creation does not enforce those hours.
- Appointment 3 was completed at 01:15:36 on the day of its 10:30 booking. Same-day check-in currently allows this; it is suspicious test timing rather than an inverted start/end timestamp.
- No inverted registration/call/start/end sequence was found in the applicable fields checked. Missing consultation start on an absent record, or no consultation for a never-called queue, is valid lifecycle behavior.
- No invalid enum status, missing queue/notification relationship, queue-room/doctor mismatch, patient/doctor role mismatch, invalid priority level, or priority sample reviewer/queue mismatch was found in the checks performed. Core foreign keys are present in MySQL. This is a targeted consistency inspection, not an exhaustive database audit.

## Appointment inspection

All seven appointments are in the past. Only appointment 3 has a queue link.

| ID | Department | Scheduled date/time | Status | Queue | Proposal |
| --- | --- | --- | --- | --- | --- |
| 1 | Dental Clinic | 6 Oct 12:00 | cancelled | None | Delete old booking |
| 2 | Health Screening | 12 Oct 08:30 | cancelled | None | Delete old booking |
| 3 | General Consultation | 15 Oct 10:30 | completed | 4 | Delete after queue 4 |
| 4 | Pharmacy | 16 Oct 12:00 | cancelled | None | Delete old booking |
| 5 | Pharmacy | 16 Oct 10:30 | cancelled | None | Delete old booking |
| 6 | General Consultation | 19 Oct 10:30 | **pending** | None | Delete stale unresolved test booking |
| 7 | Dental Clinic | 21 Oct 10:30 | **confirmed** | None | Delete stale unresolved test booking |

Pending/confirmed past appointments can interfere with account/department-management dependency checks. The existing system does not automatically mark them absent. Deleting these six unlinked appointments is an explicit additional selection, not an automatic consequence of deleting queues.

## Priority training data

There is one training row: **sample 1**, queue **5**, Health Screening (department 3), walk-in, recorded review wait **2 minutes**, priority **2**, reviewer user **19**, reviewed **20 October 2026 12:16:13**. Reviewer 19 has staff role. Its queue fields and stored approved priority agree. The sample's existence is not clinical validation; it is development data. It is included in the proposed dependency deletion.

## Foreign-key and logical dependencies

| Reference | Enforcement | Handling |
| --- | --- | --- |
| consultations.queue_id → queues.queue_id | Actual MySQL FK | Delete selected consultation children first |
| notifications.queue_id → queues.queue_id | Actual MySQL FK | Delete only notifications linked to selected queues first |
| priority_training_samples.queue_id → queues.queue_id | Logical link, unique index but no FK | Explicitly delete selected queue samples first |
| queues.appointment_id → appointments.appointment_id | Actual MySQL FK | Delete selected queues before selected appointments; refuse if another preserved queue references an appointment |
| audit_logs.record_type / record_id | Logical polymorphic reference, no FK | Preserve as historical activity; 56 entries reference the selected queues/appointments |
| push_devices.last_notification_id | Delivery watermark, no FK | Preserve; notification IDs are not renumbered or reset |

Queue records also reference users, departments, rooms and verifying staff. These are parent/configuration records and are **not deletion targets**. The model layer only defines User/Role Eloquent models and their role relation; queue operations largely use Laravel's query builder. The cleanup must therefore inspect real SQL constraints, not rely on Eloquent cascading behavior.

No additional inbound foreign keys to the selected operational tables were found. The prepared command rechecks them and refuses an unreviewed new inbound FK.

## Impact on Reports and AI

The existing `ReportController::index()` was called read-only with an active administrator resolver for **1 October–15 November 2026**. Actual results:

| Metric | Result |
| --- | ---: |
| Queues | 9 |
| Active | 2 |
| Completed | 5 |
| Average recorded wait | **6,274.5 minutes** |

The average uses six called queues, including the absent queue. The same timestamps are used by the administrator all-time summary. Removing only queue 6 from that arithmetic would leave approximately **10.7 minutes** across the other five called records. This is a counterfactual diagnostic, not a database change or a proposal to alter the formula.

If the full proposed selection were deleted, only queue 9 would remain: active=1, completed=0, and recorded average wait would be **null/empty**, because it has not been called. It would not mean zero-minute waiting performance.

The duration model's valid-sample test is merely `0 < duration < 240` minutes. Therefore all five short completed records currently pass:

| Department | Accepted duration samples | Current method |
| --- | ---: | --- |
| Dental Clinic | 0 | Configured average if an estimate is requested |
| General Consultation | 3 | Configured average, insufficient history |
| Health Screening | 2 | Configured average, insufficient history |
| Pharmacy | 0 | Configured average if an estimate is requested |

The threshold is 20 per department. Current `Clinic::estimates()` calls for queues 7 and 9 returned configured-average methods with two and three historical samples, respectively; both had zero people ahead and a calculated zero-minute wait in the inspected workload. The duration fallback itself is still **15 minutes**. A zero wait with nobody ahead does not mean a zero consultation duration.

Queue 6's enormous registration-to-call wait does **not** directly become the duration training target; its nine-second consultation does. Those are separate calculations. The single priority sample cannot satisfy the requirement for five comparable historical cases. After approved cleanup, those historical samples would be gone, allowing subsequent clearly tagged synthetic data to be evaluated separately.

## Prepared command and safeguards

Run this from `backend/` to reproduce the preview:

```powershell
php artisan sqs:cleanup-development --queues=1,2,3,4,5,6,7,8 --appointments=1,2,3,4,5,6,7 --dry-run
```

The default without `--execute` is also a dry run. This exact dry-run command has been executed successfully. No deletion command has been executed.

Prepared behavior for a future approved execution:

1. Require local environment and a configured loopback MySQL host.
2. Require explicit positive IDs; refuse ranges, wildcard selection, missing rows, today's/future queues and today's/future appointments.
3. Display selected IDs, all affected counts and a content fingerprint.
4. Require `--execute` and an interactive exact confirmation phrase. Non-interactive execution is refused; there is no force option. Combining dry-run and execute is rejected.
5. Create a **new** verified backup after confirmation and before deletion.
6. In a transaction, lock clinic settings and selected rows. Recompute the plan and reject any changed target/dependency rows or changes to operational tables since backup.
7. Delete priority samples, queue-linked notifications and consultations; then selected queues; then selected appointments. Foreign-key checks remain enabled.
8. Verify affected counts against the preview; rollback on a mismatch or exception.
9. Append one audit entry containing the selection/counts and backup reference. Do not send any notification or email.

For this exact scope, the typed phrase would be `DELETE 8 QUEUES 7 APPOINTMENTS`. The actual destructive execution remains pending approval. No `migrate`, database reset, truncation, or foreign-key-disable command is used by this cleanup.

Pause development app activity and the scheduler before a future approved cleanup, then regenerate the preview. The commands do not stop processes automatically. During this inspection an existing access-token row changed, consistent with concurrent app activity; the backup comparison detected that change. No queue/configuration/account row changes were found by that comparison. A fresh backup is required at execution time rather than assuming today's earlier snapshot remains current.

## Existing verified backup

The earlier AI-data request authorized a backup, which was created before the request changed to cleanup preview:

- SQL: `.tmp/sqs-ai/backups/20261115-154458-c92b42/database.sql`
- Receipt: `.tmp/sqs-ai/backups/20261115-154458-c92b42/manifest.json`
- Size: **132,167 bytes**
- Tables: **15**
- SHA-256: `388f41c30d3fb42ede9dd00745f1447185aabe36d472dd44fc048f16cfa9de4b`

Verification checked successful mysqldump exit, readable SQL, completion footer, CREATE TABLE presence and single-row INSERT counts for every table, stable row hashes before/after export, and the dump's SHA-256. It is a readable verified export, **not a tested restore rehearsal**. No separate database was created. The backup includes development account/token material, belongs in the Git-ignored `.tmp` folder and should not be published.

The backup command is:

```powershell
php artisan sqs:ai-backup
```

It defaults to XAMPP's mysqldump executable and supports `--mysqldump=<path>`. It reads existing Laravel connection settings, uses a temporary client option file rather than a password command-line argument, and removes that file afterward. It does not change credentials or database settings.

### Restore procedure — documentation only; not executed

Restoring the full SQL dump replaces tables and returns **the entire database** to the backup point, including users/settings/session records. It can overwrite changes made afterward. First stop the API/scheduler and take a new backup of any newer state that must be retained. Restore only after explicitly deciding to revert.

Open MySQL interactively using the existing database username, with password prompting if applicable:

```powershell
& 'C:\xampp\mysql\bin\mysql.exe' --host=127.0.0.1 --port=3306 --user=<existing-database-user> --password smart_queue_system
```

Inside the MySQL client, execute a SOURCE statement pointing to the chosen dump. For this backup:

```sql
SOURCE C:/Users/Arin Ja/FlutterProjects/smart_queue_system/.tmp/sqs-ai/backups/20261115-154458-c92b42/database.sql;
```

Then check the restored table counts against the manifest, verify user/department/room/settings availability, and restart the application. Do not paste a credential into this document. The cleanup never uses restoration or disables FK checks; the standalone mysqldump recovery file contains the standard restoration directives supplied by the dump utility.

## Files and validation

- `backend/app/Console/Commands/BackupAiDevelopment.php`: backup command.
- `backend/app/Services/DevelopmentDatabaseBackup.php`: backup/receipt verification and row fingerprints.
- `backend/app/Console/Commands/CleanupDevelopmentQueues.php`: preview and guarded interactive cleanup command.
- `backend/app/Services/DevelopmentQueueCleanup.php`: ID selection, dependency plan, transactional execution.
- `backend/tests/Feature/DevelopmentQueueCleanupTest.php`: isolated SQLite preview and selection tests.
- This document: findings, proposed selection, safeguards and recovery procedure.
- Ignored `.tmp` inspection scripts/JSON: local read-only evidence without copying account names, credentials or visit reasons into the report.

Executed validation: **7 tests passed, 18 assertions**, covering read-only previews, selected dependency counts, stable/changed fingerprints, protection of today's queues/future appointments, preserved-parent references, missing IDs and wildcard rejection. PHP syntax checks passed for the four command/service files. No local MySQL deletion or restore has been tested or performed. Transactional execution remains unexercised against this development database until approval.

## AI-data work after approval

Synthetic seeding is paused. No seeder or generated dataset has been run. After cleanup approval and execution, re-inspect current configuration, then prepare the repeatable seed/evaluation workflow from the original request: 300 completed consultations, 150 explicitly synthetic staff-review labels, existing departments/doctors/rooms, deterministic variation, no overlap for shared doctors, no outbound messages, no automatic AI priority changes, and transparent chronological validation plus a separately held-out evaluation where feasible. Queue 9 remains real development workload unless separately selected and approved for removal.
