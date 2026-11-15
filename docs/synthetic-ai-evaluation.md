# SQS synthetic AI preparation and evaluation

**Executed 15 November 2026. Synthetic development data only. These findings do not represent real clinic performance, clinical urgency validation, or production prediction accuracy.**

Full machine-readable output: [synthetic-ai-evaluation-results.json](synthetic-ai-evaluation-results.json).

## Post-cleanup update — 15 November 2026

Following the user's request to remove the preserved waiting-time outlier, queue #6, its one consultation and 21 linked notifications were deleted transactionally. A fresh verified backup was created first at `.tmp/sqs-ai/backups/20261115-161120-df6e86/manifest.json` (SQL dump: `database.sql` in the same directory). Existing audit history was retained and a cleanup audit entry was added. Other original records, accounts and configuration were preserved.

Commands: `php artisan sqs:cleanup-development --queues=6 --dry-run`, then `php artisan sqs:cleanup-development --queues=6 --execute` with explicit confirmation, then `php artisan sqs:ai-evaluate --output=../docs/synthetic-ai-evaluation-results.json`.

The refreshed dashboard/database comparison passes: **328 total queues, 22 active, 304 completed, average waiting time 38.0 minutes** (previously 159.9 minutes). Synthetic data integrity and fingerprints still pass; synthetic-only AI evaluation results are unchanged. Combined Health Screening history now contains 101 samples (80 training, 21 validation); the historical-average method remains selected with baseline MAE 10.7434 minutes, compared with KNN MAE 12.0741, 12.1229 and 11.5291 for k = 3, 5 and 7. The linked JSON contains this latest post-cleanup evaluation.

**The sections below retain the initial, pre-cleanup evaluation snapshot. Their combined database counts and outlier discussion describe the state before queue #6 was removed.**

## 1. Database scope and preservation

The configured local database is `smart_queue_system` on loopback MySQL. Inspection found that the earlier cleanup had not been applied to this database: it still contained 9 queues, 6 consultations, 7 appointments and 1 priority training record. The user explicitly approved adding synthetic data alongside those records and reporting synthetic-only and combined results separately.

Existing accounts, passwords, roles, departments, doctor assignments, rooms, clinic settings and QR configuration were not edited. No reset, truncate, destructive migration or cleanup command was run. No new database or schema migration was created.

All pre-existing domain/configuration row hashes matched the backup after insertion. One pre-existing `personal_access_tokens` row changed during concurrent app activity; the seeder does not update tokens. This exception is recorded rather than claiming a completely idle database.

### Fresh backup before insertion

- Manifest: `.tmp/sqs-ai/backups/20261115-160216-015f07/manifest.json`
- SQL dump: `.tmp/sqs-ai/backups/20261115-160216-015f07/database.sql`
- Size: **132,167 bytes**, **15 tables**.
- SHA-256: `54c8ea766c5187ed8a391762478c12aefc39a3454f344468c8301aa98f621380`

Verification checked successful mysqldump exit, readable export/completion footer, every table's DDL and individual INSERT count, stable row hashes during backup, and the resulting file checksum. **A restore rehearsal was not performed.** The private dump is Git-ignored and includes account/session material; it should not be published with a thesis.

Recovery uses the existing database credentials and the MySQL client's `SOURCE` command with this dump, after stopping application activity and backing up any newer work. Full restoration overwrites the database back to the backup point. See [cleanup preview recovery guidance](development-cleanup-preview.md#restore-procedure--documentation-only-not-executed), substituting the fresh backup path above. No restoration was executed.

## 2. Records generated

| Entity | Inserted | Explanation |
| --- | ---: | --- |
| Completed consultations | **300** | 100 each for Dental Clinic, General Consultation, Health Screening |
| Active queues | **20** | 5 waiting, 5 verified, 8 assigned, 1 called, 1 in consultation |
| Total queues | **320** | 300 historical completed + 20 active |
| Total consultation rows | **302** | 300 completed + 2 called/in-progress lifecycle rows |
| Priority training examples | **150** | 50 simulated staff-reviewed examples per selected department |
| Appointments | **30** | 18 completed linked historical bookings + 6 pending and 6 confirmed future bookings |
| Synthetic patient accounts | **332** | Separate accounts for 320 queue visits and 12 future bookings |
| Dataset receipt audit entry | **1** | Seed, anchor, inserted IDs, source hashes, dataset fingerprint and backup reference |
| Synthetic notifications / device tokens / login tokens | **0 / 0 / 0** | No outbound recipients registered |

The database therefore contains 329 queues, 308 consultation rows, 37 appointments, 151 priority samples and 380 users when the preserved records are included. There are 305 completed consultations/queues and 22 active queues. The existing 147 notifications were unchanged during the verification pass.

### Identifiers and account behavior

- Patients: `SYN-AI-V1-0001` through `SYN-AI-V1-0332`, named `SYNTHETIC AI Patient ...`.
- Addresses: reserved non-deliverable `sqs-ai-v1-...@example.invalid`.
- Historical queue numbers: `SAI1-H0001` through `SAI1-H0300`.
- Active queue numbers: `SAI1-A001` through `SAI1-A020`.
- Passwords are hashed from a random undisclosed value. No existing password was changed and no usable shared password was published.
- Accounts are active to keep staff workflow validations valid. Use existing staff/doctor/admin accounts to inspect them; patient login credentials are deliberately not supplied.

### Reproducibility and generation assumptions

Business-data randomness uses PHP's `Randomizer` with `Mt19937`, seed **20261115**. The immutable snapshot timestamp is **2026-11-15 15:00:00 Asia/Kuala_Lumpur**. Existing configuration and room/doctor assignments are inputs to generation. Password hashing is intentionally cryptographically random; reproducibility refers to operational fixture generation, not identical password hashes or auto-increment IDs across databases.

Historical records begin on **28 July 2026** and span multiple weekdays before the snapshot. Consultations use current configured hours, 08:00–17:00. A per-doctor calendar prevents overlap, including doctor 7 shared by Dental and Health Screening. Existing consultation intervals are also checked when allocating history. Pharmacy remains unchanged: it is not selected for consultation-duration evaluation, even though it has a configured room.

Durations combine department-level means, wide log-normal noise, modest appointment effects, random variation and occasional longer encounters. Generated completed durations are bounded to approximately 4–66 minutes. Registration-to-call waits vary between 6 and 75 minutes. Reasons use recurring phrases, variants, and uncommon requests. Priority labels include deliberate disagreement and overlap and do not encode a clinical triage policy. Generator parameters were not adjusted after seeing evaluation scores.

Exactly 18 historical visits have corresponding completed appointments (6 per department); the other 282 are walk-ins. Active records are walk-ins. Future appointment examples occupy valid weekday slots with available doctor/room references and capacity checks. Only 12 of the 30 appointment records are pending/confirmed workflow cases; the remaining 18 test linked historical completion.

Active fixture times are relative to the fixed Sunday snapshot. The current application permits walk-in registration based on `registration_open`, independently of weekday booking rules. Historical consultations and appointment bookings obey weekdays; the Sunday active records are specifically a queue-monitoring demonstration, not evidence of normal weekend clinic operation.

Staff references identify existing active staff users. The labels are **simulated staff decisions**, not a claim that those people actually reviewed these visits. The queue note explicitly says synthetic and not clinically validated. No model recommendation was used to write a queue priority.

### Safe reruns

All inserts run inside one transaction under the clinic settings row lock. Existing records are preserved. A versioned `seed_ai_v1` audit receipt records all inserted IDs and a full dataset fingerprint. Rerunning the same seeder verifies that receipt and inserts nothing. If someone has subsequently edited a synthetic record, the seeder refuses to overwrite or duplicate it. A namespace collision without a receipt is also rejected.

**Observed second run: inserted 0; already_present=true.** The generated dataset fingerprint was unchanged after evaluation. A new variant requires an explicitly reviewed version rather than silently changing this one.

## 3. Notification protection

A local-only safety marker at `.tmp/sqs-ai/outbound-paused` was enabled before insertion. It pauses:

- Laravel mail through a `MessageSending` event veto.
- FCM push delivery before credentials or network access.
- Scheduled appointment reminders and waiting-time alert generation.

This prevents active synthetic workload from indirectly triggering real push updates for preserved test patients. It does not modify `.env`, credentials, clinic settings, or QR codes. The guard applies only when `APP_ENV=local`; test/production environments are not automatically paused by the local marker.

Seeder inserts use the query builder without account-created email events or calls to `Clinic::notify`. Evaluation reads model/report data and does not call Groq or send email/push. Verification found:

- Inbox count before/after the guarded refresh: **147 → 147**.
- Push returned zero before the credential path could run.
- The mail-send event returned false.
- No synthetic inbox records, push devices, or login tokens.

**Notifications remain paused intentionally.** Inspect the status with:

```powershell
php artisan sqs:ai-notifications
```

Only after finishing the synthetic demonstration, resume deliberately with:

```powershell
php artisan sqs:ai-notifications --resume
```

Resuming may deliver existing pending alerts and enables further reminders. Do not resume merely to rerun the evaluation. While paused, ordinary account-email workflows may not actually deliver mail even if a UI reports submission; this is an explicit local evaluation limitation. Long-lived workers started before these code changes may require restarting to load the guard. No running worker was terminated by this task.

## 4. Existing duration algorithm and main validation results

`QueueIntelligence.php` and `Clinic.php` were inspected and left unchanged. Their SHA-256 hashes were recorded before insertion and checked after evaluation. These algorithms learn from database history on demand; there is no separately saved trained model artifact.

The implementation requires **20 valid completed consultations per department**, splits them chronologically into the oldest 80% for training and newest 20% for validation, evaluates k=3/5/7 and compares KNN validation MAE with a training-average baseline. KNN is selected only when it strictly beats the baseline. The evaluation diagnostics invoke the original private regression method via reflection rather than introducing another KNN implementation, then check the selected result against the public service.

**Synthetic-only results; MAE is in consultation-duration minutes.**

| Department | Samples | Train | Validation | KNN k=3 MAE | KNN k=5 MAE | KNN k=7 MAE | Average baseline MAE | Selected method |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Dental Clinic | 100 | 80 | 20 | **8.3236** | 8.8448 | 8.4335 | 8.4151 | KNN, k=3 |
| General Consultation | 100 | 80 | 20 | 9.8003 | 9.5288 | **9.0808** | 9.6144 | KNN, k=7 |
| Health Screening | 100 | 80 | 20 | 11.4892 | 11.6088 | 10.8996 | **10.0425** | Historical average |

Selected-method MAEs exposed by the service are rounded to **8.32**, **9.08** and **10.04** minutes. Health Screening's best candidate is k=7, but it is rejected in favor of the baseline. A best candidate k is not the same as a selected KNN model.

For each department, a separate call with only 19 samples returned the configured **15-minute** duration and no validation MAE. The 20-sample threshold and 16/4 split are also covered by an automated test.

**The main holdout is used to choose k and choose between KNN and the baseline. It must not be presented as independent final test accuracy.** MAE here describes consultation duration, not a measured end-to-end waiting-time prediction error.

### Additional chronological test protocol

Within each department, the first 80 records form a development subset, split into 64 training and 16 model-selection validation records. The final 20 records are excluded from that selection and evaluated afterward through the public duration service. No test label enters the development input.

| Department | Development / inner train / inner validation / test | Selected on development | Held-out test MAE |
| --- | --- | --- | ---: |
| Dental Clinic | 80 / 64 / 16 / 20 | KNN k=5 | 8.8448 |
| General Consultation | 80 / 64 / 16 / 20 | KNN k=5 | 9.5292 |
| Health Screening | 80 / 64 / 16 / 20 | KNN k=3 | 11.4885 |

The chosen k differs from the full-dataset main validation because the development subset is different. Predictions are evaluated at each held-out consultation's start hour, rather than the current wall-clock hour. This is an independent partition **within the synthetic evaluation protocol**, not an independent clinical dataset. All inserted history remains visible to normal production service queries; the application was not redesigned to maintain train/test partitions.

### Combined runtime history with preserved records

The current application sees generated and pre-existing completed records together (all below its 500-record lookback cap):

| Department | Valid samples | Train / validation | Selected method | Selected validation MAE |
| --- | ---: | --- | --- | ---: |
| Dental Clinic | 100 | 80 / 20 | KNN k=3 | 8.32 |
| General Consultation | 103 | 82 / 21 | KNN k=7 | 10.42 |
| Health Screening | 102 | 81 / 21 | Historical average | 11.54 |

The older 5–79-second completed consultations remain accepted by the production rule `0 < duration < 240`. No filter or algorithm was changed to hide them. This is why synthetic-only thesis tables and runtime application values differ.

## 5. Priority recommendation evaluation

The evaluator retrieved all **150** synthetic rows by their receipt IDs. The application currently has **151** total priority samples including the original one. Per department, the earliest 40 synthetic reviews are training and the final 10 are held out. Predictions use the queue and time at that review so waiting minutes do not accidentally become months-long waits during retrospective evaluation. Held-out labels are excluded from each department's training input.

| Department | Training | Held out | Recommended | Abstained | Matches among recommendations |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dental Clinic | 40 | 10 | 9 | 1 | 4 |
| General Consultation | 40 | 10 | 5 | 5 | 3 |
| Health Screening | 40 | 10 | 9 | 1 | 4 |
| **Total** | **120** | **30** | **23** | **7** | **11** |

- Recommendation coverage: **23/30 = 76.67%**.
- Abstention rate: **7/30 = 23.33%**.
- Agreement with held-out synthetic labels when a recommendation was made: **11/23 = 47.83%**.
- Correct recommendations as a fraction of all held-out cases: **11/30 = 36.67%**. This separate denominator must not be confused with conditional agreement.

The results indicate substantial disagreement in this intentionally noisy dataset. They do not support a claim of clinically reliable urgency classification.

Controlled probes exercised the unmodified similarity/voting logic:

| Probe | Actual result |
| --- | --- |
| Five comparable cases with votes 1,1,1,0,2 | Recommend 1, agreement 0.6 |
| Five comparable cases with votes 0,0,1,1,2 | Abstain: decisions disagree |
| Only four comparable cases | Abstain: insufficient cases |
| Empty reason | Abstain |
| Unrelated reason vocabulary | Abstain |

Live recommendations were also calculated from the existing latest-500-sample retrieval pattern for eligible active queues. Database queue order and the full synthetic fingerprint were unchanged afterward. An API test confirms that a patient cannot set priority, a blank staff reason is rejected, and a valid staff approval writes the training sample. These are authorization and non-mutation checks, not proof of medical suitability.

## 6. Waiting-time workload verification

`Clinic::estimates()` was run on all **22** active queues at the frozen snapshot (20 synthetic, 2 preserved). It used the current department/doctor workload, priority ordering, capacity and elapsed in-progress consultation time. The JSON artifact contains each queue's people-ahead count, method and calculated wait.

Examples at the snapshot:

| Queue ID | Synthetic? | State | People ahead | Estimated wait |
| --- | --- | --- | ---: | ---: |
| 310 | Yes | waiting | 1 | 27 minutes |
| 311 | Yes | waiting | 1 | 11 minutes |
| 312 | Yes | waiting | 1 | 26 minutes |
| 316 | Yes | verified | 3 | 79 minutes |
| 9 | No | verified | 3 | 41 minutes |

Values can differ in the UI as real time advances: in-progress elapsed time and current-hour duration features change. Active fixtures do not automatically advance their own statuses. A focused PHPUnit test verifies that a 15-minute fallback consultation started five minutes ago contributes ten remaining minutes, while a skipped queue contributes no workload.

The shared doctor across departments also exposes a limitation of the existing implementation: workload estimation filters to the target department, while the call restriction checks doctor occupancy globally. Estimates are approximate and can miss cross-department occupancy. This task does not change that algorithm.

## 7. Dashboard and report verification

The existing administrator `WorkspaceController` summary and `ReportController` were invoked read-only. Results were compared against separate SQL aggregate queries using `TIMESTAMPDIFF(SECOND, registered_at, called_at)/60`, bounded below by zero, matching the existing registration-to-call definition. The evaluated report interval was **28 July–15 November 2026**.

| Metric | Synthetic only | Combined current database / Dashboard / Report |
| --- | ---: | ---: |
| Total queues | 320 | 329 |
| Active queues | 20 | 22 |
| Completed queues | 300 | 305 |
| Recorded average wait | 38.4 minutes | 159.9 minutes |

Combined departmental distribution: **Dental 109, General Consultation 111, Health Screening 109**. Pharmacy has no queue rows in this interval and is omitted from the grouped report. The administrator still has four active departments.

**All checked metrics match the independent SQL.** The average includes every called queue, including called/in-progress/absent records, not just completed consultations. It is distinct from predicted waiting time and from consultation-duration MAE.

Preserved queue **6** has a **37,593.58-minute** registration-to-call wait. It inflates the combined result even after adding realistic synthetic history. This record was identified and left unchanged as authorized. No reporting formula was changed to improve the apparent result.

This verifies the backend payloads powering the pages. It does not claim a new physical-device or Flutter screenshot inspection. The workspace still caps loaded queue lists at 250; the administrator summary/report and historical calculation use their separate database queries. Staff/doctor card totals based on loaded lists can therefore differ from all-record totals.

## 8. Integrity and functional tests

Actual MySQL checks returned zero for:

- Invalid historical registration/call/start/end order.
- Completed queue/consultation state mismatch.
- Historical weekend visits or visits outside current operating hours.
- Doctor/room/department assignment mismatch.
- Missing queue patients or priority queue/reviewer references.
- Priority field mismatch against the approved queue value.
- Completed appointment/queue mismatch.
- Overlap among generated historical consultations for the same doctor.
- Synthetic notifications, device registrations or access tokens.

MySQL foreign keys remained enabled throughout. The seeder uses the actual custom keys and enum states. It additionally checks appointment slot capacity and existing doctor bookings; it does not change current room or doctor configuration.

### PHPUnit run

```powershell
php artisan test --log-junit=../.tmp/sqs-ai/phpunit.xml
```

| Result | Actual count |
| --- | ---: |
| Tests passed | **50** |
| Assertions | **330** |
| Failures | **0** |
| Errors | **0** |
| Skipped | **0** |

The test suite is forced to isolated SQLite `:memory:` by its existing configuration. It did not reset the local MySQL database. The JUnit output was parsed to confirm failure/error/skipped counts. Live MySQL integrity/report checks and SQLite tests are separate evidence.

Six AI-specific tests were added: 19/20-sample threshold and chronological split, diagnostic/public-service parity, majority-disagreement abstention with priority preservation, local safety isolation from testing, staff approval/reason enforcement, and workload elapsed-time/skipped handling. Existing authentication, queue/appointment, push, import, chat and report-related tests also ran.

The local safety guard was separately exercised with a push subclass that throws if credentials are accessed, a mail event without any network transport, and a guarded notification refresh. This verified suppression without contacting an external service.

## 9. Commands executed

All Artisan commands below were run from `backend/`:

```powershell
# Focused validation before inserting:
php artisan test --filter='SyntheticAiEvaluationTest|ai_priority_requires|wait_workload'

# Creates a fresh verified backup internally, then executes the Laravel Seeder:
php artisan sqs:ai-seed --as-of='2026-11-15 15:00:00' --seed=20261115

# Initial evaluation:
php artisan sqs:ai-evaluate

# Idempotency verification; actually inserted zero:
php artisan sqs:ai-seed --as-of='2026-11-15 15:00:00' --seed=20261115

# Entire existing and expanded backend suite:
php artisan test --log-junit=../.tmp/sqs-ai/phpunit.xml

# Persist current read-only evaluation results with the documentation:
php artisan sqs:ai-evaluate --output=../docs/synthetic-ai-evaluation-results.json
```

PHP syntax checks and local read-only schema/row-hash/safety inspection scripts were also run. The attempted Windows process inventory returned **Access denied**, so it was not used to claim that a scheduler was stopped. No scheduler process was terminated; the explicit local safety guard was used instead. The seeder, evaluation and full PHPUnit run completed without reported failures.

## 10. Files created or modified for this run

New:

- `backend/database/seeders/SyntheticAiDatasetSeeder.php`
- `backend/app/Console/Commands/SeedAiDataset.php`
- `backend/app/Console/Commands/EvaluateAiDataset.php`
- `backend/app/Console/Commands/AiNotificationSafety.php`
- `backend/app/Services/SyntheticAiEvaluation.php`
- `backend/app/Services/SyntheticAiSafety.php`
- `backend/tests/Unit/SyntheticAiEvaluationTest.php`
- `docs/synthetic-ai-evaluation.md`
- `docs/synthetic-ai-evaluation-results.json`
- Git-ignored backup, seed receipt output, safety evidence, marker and JUnit artifacts under `.tmp/sqs-ai/`.

Modified:

- `backend/app/Providers/AppServiceProvider.php`: local mail-event safety guard.
- `backend/app/Services/FirebasePush.php`: early local safety pause.
- `backend/app/Services/ClinicNotifications.php`: local scheduled-alert safety pause.
- `backend/tests/Feature/ClinicWorkflowTest.php`: staff-priority and workload tests.

Reused from the earlier cleanup preparation: `DevelopmentDatabaseBackup.php` and the backup command. Earlier cleanup files were not executed for deletion. `QueueIntelligence.php`, `Clinic.php`, report formulas, migrations, Flutter pages, account credentials and existing configuration were not changed. An unrelated `.vscode/settings.json` change appeared during the work and was left alone.

## 11. How to inspect through the app

1. Run the API and Flutter app as usual. Keep the local notification pause while demonstrating synthetic records.
2. Sign in with an existing administrator. Home should show **329 total, 22 active, 305 completed**, and **159.9 minutes** average recorded wait for the unchanged snapshot.
3. In Reports, choose **28 July 2026 through 15 November 2026**, all departments. Compare totals and 109/111/109 distribution with this report. A narrower date range intentionally changes the numbers.
4. In Users, search `SYNTHETIC AI` or identifiers beginning `SYN-AI-V1-`. No user password needs to be changed for admin inspection.
5. Sign in as staff. Monitor shows active `SAI1-A...` queues. Verify includes five waiting queues plus six pending synthetic future appointments. Assign shows eligible verified/assigned cases and historical priority recommendations.
6. Sign in as the assigned doctor. Call/Consult can show the synthetic called/in-progress visit. Doctor 7 is shared across several departments, so a called patient can block another call globally.
7. Before editing any synthetic queue or appointment, retain the JSON evaluation artifact. Manual workflow changes deliberately invalidate the seed fingerprint; subsequent seed/evaluation commands refuse to silently overwrite the altered dataset.

Known existing UI issue: the Flutter queue/prediction widgets detect learned estimates with an `AI:` prefix while the backend now returns `KNN regression (...)`. Some UI captions can therefore call KNN output an average. This task preserves the algorithm/UI implementation and reports the actual server-selected method from the JSON evaluation.

## 12. Concise Chapter 4 evaluation summary

The Smart Queue System was evaluated using reproducible synthetic development data inserted into the existing local MySQL database after a verified backup. The dataset contained 300 completed consultations, distributed equally across Dental Clinic, General Consultation and Health Screening, together with 150 simulated staff-reviewed priority examples, 20 active queues and 30 appointment records. Existing development records and configuration were preserved. The original prediction algorithms were unchanged.

For consultation-duration prediction, each department supplied 80 chronological training and 20 validation records. KNN selected k=3 for Dental Clinic, with validation MAE of 8.32 minutes compared with an 8.42-minute historical-average baseline. General Consultation selected k=7, with MAE of 9.08 minutes compared with 9.61 minutes for the baseline. Health Screening retained the historical average, whose MAE of 10.04 minutes was lower than all evaluated KNN candidates. Because this validation partition was used for model selection, these values are not independent final test accuracy. An additional chronological evaluation using 64 training, 16 selection-validation and 20 held-out records per department produced test MAEs of 8.84, 9.53 and 11.49 minutes respectively.

Priority evaluation used 120 training and 30 held-out synthetic labels. The algorithm issued recommendations for 23 cases (76.67%) and abstained for seven (23.33%). Eleven recommendations matched the held-out labels, giving 47.83% agreement among recommended cases. Controlled tests confirmed abstention for insufficient, unrelated or conflicting examples, and recommendations did not change approved queue priorities. All 50 PHPUnit tests passed, with 330 assertions and no failures, errors or skipped tests. Dashboard and report calculations matched independent SQL aggregates. These results demonstrate implementation behavior on synthetic data; they do not establish real-clinic prediction accuracy or clinically validated urgency classification.
