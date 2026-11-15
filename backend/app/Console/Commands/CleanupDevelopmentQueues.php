<?php

namespace App\Console\Commands;

use App\Services\DevelopmentDatabaseBackup;
use App\Services\DevelopmentQueueCleanup;
use Illuminate\Console\Command;

class CleanupDevelopmentQueues extends Command
{
    protected $signature = 'sqs:cleanup-development {--queues= : Explicit comma-separated obsolete queue IDs}
        {--appointments= : Explicit comma-separated past appointment IDs}
        {--dry-run : Preview only (also the default)}
        {--execute : Request deletion, with fresh backup and typed confirmation}
        {--mysqldump=C:/xampp/mysql/bin/mysqldump.exe}';
    protected $description = 'Preview selected development queue cleanup; preserve accounts, configuration and audit history';

    public function handle(DevelopmentQueueCleanup $cleanup, DevelopmentDatabaseBackup $backup): int
    {
        DevelopmentDatabaseBackup::assertLocal();
        if ($this->option('dry-run') && $this->option('execute')) {
            $this->error('Choose dry-run or execute, not both.');
            return self::FAILURE;
        }
        $plan = $cleanup->plan(DevelopmentQueueCleanup::ids($this->option('queues')), DevelopmentQueueCleanup::ids($this->option('appointments')));
        $this->table(['Table', 'Existing', 'Would delete', 'Preserve'], collect($plan['counts'])->map(fn ($v, $k) => [$k, $v['existing'], $v['delete'], $v['preserve']])->values()->all());
        $this->line('Queue IDs: '.implode(',', $plan['queue_ids']));
        $this->line('Appointment IDs: '.implode(',', $plan['appointment_ids']));
        $this->line('Preserve all users, roles, rooms, departments, clinic settings/QR, sessions, push registrations and audit history.');
        $this->line('Preserved audit references to selected records: '.$plan['preserved_audit_references']);
        $this->line('Unlinked notifications are preserved: there is no appointment FK to identify them reliably.');
        $this->line('Plan fingerprint: '.$plan['fingerprint']);
        if (! $this->option('execute')) {
            $this->info('DRY RUN ONLY. No database writes, backup changes, deletion or notifications.');
            return self::SUCCESS;
        }
        if (! $this->input->isInteractive()) {
            $this->error('Deletion requires interactive typed confirmation. Non-interactive execution is refused.');
            return self::FAILURE;
        }
        $phrase = 'DELETE '.count($plan['queue_ids']).' QUEUES '.count($plan['appointment_ids']).' APPOINTMENTS';
        if ($this->ask('Type exactly: '.$phrase) !== $phrase) {
            $this->info('Cancelled. No deletion.');
            return self::SUCCESS;
        }
        $manifest = $backup->create($this->option('mysqldump'));
        $this->info('Fresh verified backup: '.$manifest);
        $affected = $cleanup->execute($plan, $manifest, $backup);
        $this->info('Committed selected cleanup: '.json_encode($affected));
        $this->line('Original audit history retained; one cleanup audit entry appended.');

        return self::SUCCESS;
    }
}
