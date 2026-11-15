<?php

namespace Tests\Feature;

use App\Services\DevelopmentQueueCleanup;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class DevelopmentQueueCleanupTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // A fresh isolated SQLite connection; no migrations or access to MySQL.
        config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
        DB::purge('sqlite');
        $this->travelTo(\Carbon\Carbon::parse('2026-11-15 12:00:00'));
        DB::unprepared(<<<'SQL'
CREATE TABLE queues (queue_id INTEGER PRIMARY KEY, queue_number TEXT, queue_status TEXT, registered_at TEXT, appointment_id INTEGER);
CREATE TABLE appointments (appointment_id INTEGER PRIMARY KEY, appointment_date TEXT, appointment_status TEXT);
CREATE TABLE consultations (consultation_id INTEGER PRIMARY KEY, queue_id INTEGER);
CREATE TABLE notifications (notification_id INTEGER PRIMARY KEY, queue_id INTEGER);
CREATE TABLE priority_training_samples (id INTEGER PRIMARY KEY, queue_id INTEGER);
CREATE TABLE audit_logs (id INTEGER PRIMARY KEY, record_type TEXT, record_id INTEGER);
INSERT INTO appointments VALUES (1, '2026-10-01', 'completed');
INSERT INTO queues VALUES (1, 'OLD-1', 'completed', '2026-10-01 08:00:00', 1);
INSERT INTO queues VALUES (2, 'TODAY-2', 'verified', '2026-11-15 08:00:00', NULL);
INSERT INTO consultations VALUES (1, 1);
INSERT INTO notifications VALUES (1, 1), (2, 2), (3, NULL);
INSERT INTO priority_training_samples VALUES (1, 1);
INSERT INTO audit_logs VALUES (1, 'queue', 1);
SQL);
    }

    protected function tearDown(): void
    {
        $this->travelBack();
        DB::purge('sqlite');
        parent::tearDown();
    }

    public function test_preview_counts_only_selected_dependencies_and_writes_nothing(): void
    {
        $before = [];
        foreach (['queues', 'appointments', 'consultations', 'notifications', 'priority_training_samples', 'audit_logs'] as $table) {
            $before[$table] = DB::table($table)->get()->toJson();
        }
        $service = new DevelopmentQueueCleanup;
        $plan = $service->plan([1], [1]);
        $this->assertSame(['existing' => 3, 'delete' => 1, 'preserve' => 2], $plan['counts']['notifications']);
        $this->assertSame(1, $plan['counts']['consultations']['delete']);
        $this->assertSame(1, $plan['counts']['priority_training_samples']['delete']);
        $this->assertSame(1, $plan['preserved_audit_references']);
        $this->assertSame($plan['fingerprint'], $service->plan([1], [1])['fingerprint']);
        foreach ($before as $table => $rows) {
            $this->assertSame($rows, DB::table($table)->get()->toJson());
        }
        DB::table('notifications')->insert(['notification_id' => 4, 'queue_id' => 1]);
        $this->assertNotSame($plan['fingerprint'], $service->plan([1], [1])['fingerprint']);
    }

    public function test_preserved_queue_prevents_appointment_deletion(): void
    {
        $this->expectExceptionMessage('referenced by a preserved queue');
        (new DevelopmentQueueCleanup)->plan([], [1]);
    }

    public function test_today_queue_is_protected(): void
    {
        $this->expectExceptionMessage('registered today or later');
        (new DevelopmentQueueCleanup)->plan([2], []);
    }

    public function test_missing_records_are_not_silently_ignored(): void
    {
        $this->expectExceptionMessage('missing records');
        (new DevelopmentQueueCleanup)->plan([999], []);
    }

    public function test_wildcard_selection_is_rejected(): void
    {
        $this->expectExceptionMessage('without ranges or wildcards');
        DevelopmentQueueCleanup::ids('*');
    }

    public function test_ids_are_sorted_and_deduplicated(): void
    {
        $this->assertSame([1, 3], DevelopmentQueueCleanup::ids('3,1,3'));
    }

    public function test_future_appointment_is_protected(): void
    {
        DB::table('appointments')->insert(['appointment_id' => 2, 'appointment_date' => '2026-11-16', 'appointment_status' => 'confirmed']);
        $this->expectExceptionMessage('dated today or later');
        (new DevelopmentQueueCleanup)->plan([], [2]);
    }
}
