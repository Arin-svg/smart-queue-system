<?php

namespace App\Console\Commands;

use App\Services\DevelopmentDatabaseBackup;
use App\Services\SyntheticAiSafety;
use Illuminate\Console\Command;

class AiNotificationSafety extends Command
{
    protected $signature = 'sqs:ai-notifications {--resume : Remove the local outbound safety pause after testing}';
    protected $description = 'Inspect or explicitly resume local mail, push and scheduled notifications after synthetic testing';

    public function handle(): int
    {
        DevelopmentDatabaseBackup::assertLocal();
        if ($this->option('resume') && is_file(SyntheticAiSafety::path())) {
            unlink(SyntheticAiSafety::path());
        }
        $this->info(SyntheticAiSafety::paused() ? 'PAUSED: local mail, push and scheduled alert generation.' : 'Notifications are not paused.');
        return self::SUCCESS;
    }
}
