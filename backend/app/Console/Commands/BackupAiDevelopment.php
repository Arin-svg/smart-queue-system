<?php

namespace App\Console\Commands;

use App\Services\DevelopmentDatabaseBackup;
use Illuminate\Console\Command;

class BackupAiDevelopment extends Command
{
    protected $signature = 'sqs:ai-backup {--mysqldump=C:/xampp/mysql/bin/mysqldump.exe}';
    protected $description = 'Back up and verify the configured local development database before synthetic AI data';

    public function handle(DevelopmentDatabaseBackup $backup): int
    {
        $path = $backup->create($this->option('mysqldump'));
        $manifest = $backup->verify($path);
        $this->info('Verified backup manifest: '.$path);
        $this->line('Database: '.$manifest['database'].'; tables: '.count($manifest['tables']).'; bytes: '.$manifest['bytes']);
        $this->line('SHA-256: '.$manifest['sha256']);
        $this->line($manifest['verification']);

        return self::SUCCESS;
    }
}
