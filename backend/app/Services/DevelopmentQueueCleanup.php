<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/** Explicit ID selections only; no age-based bulk delete and no notifications. */
class DevelopmentQueueCleanup
{
    public static function ids(?string $input): array
    {
        if ($input === null || trim($input) === '') {
            return [];
        }
        if (! preg_match('/^[1-9][0-9]*(,[1-9][0-9]*)*$/D', $input)) {
            throw new RuntimeException('Use comma-separated positive IDs, without ranges or wildcards.');
        }
        $ids = array_values(array_unique(array_map('intval', explode(',', $input))));
        sort($ids);

        return $ids;
    }

    public function plan(array $queueIds, array $appointmentIds, bool $lock = false): array
    {
        if (! $queueIds && ! $appointmentIds) {
            throw new RuntimeException('Specify explicit --queues and/or --appointments IDs.');
        }
        $queues = DB::table('queues')->whereIn('queue_id', $queueIds)->orderBy('queue_id')->when($lock, fn ($q) => $q->lockForUpdate())->get();
        $appointments = DB::table('appointments')->whereIn('appointment_id', $appointmentIds)->orderBy('appointment_id')->when($lock, fn ($q) => $q->lockForUpdate())->get();
        if ($queues->count() !== count($queueIds) || $appointments->count() !== count($appointmentIds)) {
            throw new RuntimeException('Selection contains missing records; regenerate and review the preview.');
        }
        foreach ($queues as $queue) {
            if (Carbon::parse($queue->registered_at)->startOfDay()->gte(now()->startOfDay())) {
                throw new RuntimeException('Refusing a queue registered today or later: '.$queue->queue_id);
            }
        }
        foreach ($appointments as $appointment) {
            if (Carbon::parse($appointment->appointment_date)->gte(now()->startOfDay())) {
                throw new RuntimeException('Refusing an appointment dated today or later: '.$appointment->appointment_id);
            }
        }
        if (DB::table('queues')->whereIn('appointment_id', $appointmentIds)->whereNotIn('queue_id', $queueIds)->exists()) {
            throw new RuntimeException('An appointment is referenced by a preserved queue. Select it explicitly or preserve that appointment.');
        }
        // Re-inspect inbound FKs, rather than assuming future schema changes are safe.
        if (DB::connection()->getDriverName() === 'mysql') {
            $foreignKeys = DB::select('SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA = ? AND REFERENCED_TABLE_NAME IN (\'queues\', \'appointments\', \'consultations\', \'notifications\', \'priority_training_samples\')', [DB::connection()->getDatabaseName()]);
            $known = ['consultations.queue_id.queues', 'notifications.queue_id.queues', 'queues.appointment_id.appointments'];
            foreach ($foreignKeys as $key) {
                if (! in_array($key->TABLE_NAME.'.'.$key->COLUMN_NAME.'.'.$key->REFERENCED_TABLE_NAME, $known, true)) {
                    throw new RuntimeException('Unreviewed inbound foreign key: '.$key->TABLE_NAME.'.'.$key->COLUMN_NAME);
                }
            }
        }
        $selected = [];
        foreach (['priority_training_samples' => 'id', 'notifications' => 'notification_id', 'consultations' => 'consultation_id'] as $table => $key) {
            $selected[$table] = DB::table($table)->whereIn('queue_id', $queueIds)->orderBy($key)->when($lock, fn ($q) => $q->lockForUpdate())->get()->all();
        }
        $selected['queues'] = $queues->all();
        $selected['appointments'] = $appointments->all();
        $counts = [];
        $recordIds = [];
        $primaryKeys = ['priority_training_samples' => 'id', 'notifications' => 'notification_id', 'consultations' => 'consultation_id', 'queues' => 'queue_id', 'appointments' => 'appointment_id'];
        foreach ($selected as $table => $rows) {
            $counts[$table] = ['existing' => DB::table($table)->count(), 'delete' => count($rows), 'preserve' => DB::table($table)->count() - count($rows)];
            $recordIds[$table] = array_map(fn ($row) => $row->{$primaryKeys[$table]}, $rows);
        }
        $auditReferences = DB::table('audit_logs')->where(function ($q) use ($queueIds, $appointmentIds) {
            $q->where(fn ($q) => $q->where('record_type', 'queue')->whereIn('record_id', $queueIds))
                ->orWhere(fn ($q) => $q->where('record_type', 'appointment')->whereIn('record_id', $appointmentIds));
        })->count();

        return ['queue_ids' => $queueIds, 'appointment_ids' => $appointmentIds, 'counts' => $counts, 'record_ids' => $recordIds,
            'fingerprint' => hash('sha256', json_encode($selected, JSON_THROW_ON_ERROR)),
            'preserved_audit_references' => $auditReferences,
            'queue_preview' => $queues->map(fn ($q) => ['id' => $q->queue_id, 'number' => $q->queue_number, 'status' => $q->queue_status, 'registered_at' => $q->registered_at])->all(),
            'appointment_preview' => $appointments->map(fn ($a) => ['id' => $a->appointment_id, 'date' => $a->appointment_date, 'status' => $a->appointment_status])->all()];
    }

    /** Caller must already have obtained interactive approval and a fresh verified backup. */
    public function execute(array $reviewed, string $manifestPath, DevelopmentDatabaseBackup $backup): array
    {
        DevelopmentDatabaseBackup::assertLocal();
        $receipt = $backup->verify($manifestPath);
        if (Carbon::parse($receipt['created_at'])->lt(now()->subMinutes(10))) {
            throw new RuntimeException('Execution requires a fresh backup less than ten minutes old.');
        }

        return DB::transaction(function () use ($reviewed, $receipt, $manifestPath, $backup) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $current = $this->plan($reviewed['queue_ids'], $reviewed['appointment_ids'], true);
            if (! hash_equals($reviewed['fingerprint'], $current['fingerprint'])) {
                throw new RuntimeException('Selected records changed after preview. Nothing deleted; review again.');
            }
            // Do not delete anything added/modified after the backup was taken.
            $snapshot = $backup->snapshot();
            foreach (array_keys($current['counts']) as $table) {
                if ($snapshot[$table] !== $receipt['tables'][$table]) {
                    throw new RuntimeException('Operational data changed after backup; cleanup aborted.');
                }
            }
            $affected = [];
            foreach (['priority_training_samples', 'notifications', 'consultations'] as $table) {
                $affected[$table] = DB::table($table)->whereIn('queue_id', $current['queue_ids'])->delete();
            }
            $affected['queues'] = DB::table('queues')->whereIn('queue_id', $current['queue_ids'])->delete();
            $affected['appointments'] = DB::table('appointments')->whereIn('appointment_id', $current['appointment_ids'])->delete();
            foreach ($affected as $table => $count) {
                if ($count !== $current['counts'][$table]['delete']) {
                    throw new RuntimeException('Affected-count mismatch; transaction rolled back.');
                }
            }
            DB::table('audit_logs')->insert(['actor_id' => null, 'action' => 'cleanup_development_queues',
                'record_type' => 'development', 'record_id' => null,
                'details' => json_encode(['queue_ids' => $current['queue_ids'], 'appointment_ids' => $current['appointment_ids'],
                    'affected' => $affected, 'backup_manifest' => $manifestPath, 'backup_sha256' => $receipt['sha256']]), 'created_at' => now()]);

            return $affected;
        });
    }
}
