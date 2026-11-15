<?php

namespace App\Console\Commands;

use Database\Seeders\SyntheticAiDatasetSeeder;
use Illuminate\Console\Command;

class SeedAiDataset extends Command
{
    protected $signature = 'sqs:ai-seed {--as-of= : Fixed non-future snapshot timestamp} {--seed=20261115} {--mysqldump=C:/xampp/mysql/bin/mysqldump.exe}';
    protected $description = 'Back up local MySQL and add the versioned synthetic AI evaluation dataset once';

    public function handle(): int
    {
        config(['sqs_ai.as_of' => $this->option('as-of'), 'sqs_ai.seed' => $this->option('seed'), 'sqs_ai.mysqldump' => $this->option('mysqldump')]);
        $seeder = new SyntheticAiDatasetSeeder;
        $seeder->setCommand($this);
        $seeder->run();
        file_put_contents(base_path('../.tmp/sqs-ai/seed-result.json'), json_encode($seeder->result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
        $this->info(json_encode(['inserted' => $seeder->result['inserted'], 'already_present' => $seeder->result['already_present'],
            'as_of' => $seeder->result['receipt']['as_of'], 'backup_manifest' => $seeder->result['receipt']['backup_manifest']], JSON_PRETTY_PRINT));
        $this->warn('Local outbound mail/push and scheduled alerts remain paused. See sqs:ai-notifications.');
        return self::SUCCESS;
    }
}
