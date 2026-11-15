<?php

namespace App\Console\Commands;

use App\Services\DevelopmentDatabaseBackup;
use App\Services\SyntheticAiSafety;
use Illuminate\Console\Command;

class AiNotificationSafety extends Command
{
    protected $signature = 'sqs:ai-notifications {--resume : Remove the local outbound safety pause after testing} {--resume-mail : Restore real-recipient mail while keeping push and scheduled alerts paused}';
    protected $description = 'Inspect or explicitly resume local mail, push and scheduled notifications after synthetic testing';

    public function handle(): int
    {
        DevelopmentDatabaseBackup::assertLocal();
        if ($this->option('resume-mail')) {
            if (! is_dir(dirname(SyntheticAiSafety::path()))) {
                mkdir(dirname(SyntheticAiSafety::path()), 0700, true);
            }
            if (file_put_contents(SyntheticAiSafety::path().'-mail-resumed', 'Real-recipient mail restored; synthetic addresses remain blocked.') === false) {
                throw new \RuntimeException('Cannot resume mail.');
            }
        }
        if ($this->option('resume') && is_file(SyntheticAiSafety::path())) {
            unlink(SyntheticAiSafety::path());
        }
        $this->info(SyntheticAiSafety::paused() ? 'PAUSED: push and scheduled alert generation.' : 'Push and scheduled alerts are not paused.');
        $this->info(SyntheticAiSafety::mailPaused() ? 'Mail is paused.' : 'Real-recipient mail is enabled; example.invalid recipients are blocked.');
        return self::SUCCESS;
    }
}
