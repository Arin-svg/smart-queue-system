<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use RuntimeException;
use Symfony\Component\Process\Process;

/** Local-only backup receipts. Never prints connection credentials or row contents. */
class DevelopmentDatabaseBackup
{
    public static function assertLocal(): void
    {
        $connection = DB::connection();
        if (! app()->environment('local') || $connection->getDriverName() !== 'mysql'
            || ! in_array($connection->getConfig('host'), ['127.0.0.1', 'localhost', '::1'], true)) {
            throw new RuntimeException('This operation requires APP_ENV=local and the configured local MySQL connection.');
        }
    }

    public function snapshot(): array
    {
        $result = [];
        foreach (DB::select('SHOW FULL TABLES WHERE Table_type = ?', ['BASE TABLE']) as $row) {
            $table = array_values((array) $row)[0];
            $keys = DB::select('SHOW KEYS FROM `'.str_replace('`', '``', $table).'` WHERE Key_name = ?', ['PRIMARY']);
            usort($keys, fn ($a, $b) => $a->Seq_in_index <=> $b->Seq_in_index);
            $columns = array_map(fn ($k) => $k->Column_name, $keys);
            if (! $columns) {
                throw new RuntimeException('Cannot fingerprint a table without a primary key: '.$table);
            }
            $query = DB::table($table);
            foreach ($columns as $column) {
                $query->orderBy($column);
            }
            $hashes = [];
            foreach ($query->get() as $record) {
                $key = json_encode(array_map(fn ($column) => $record->$column, $columns));
                $hashes[$key] = hash('sha256', json_encode((array) $record, JSON_THROW_ON_ERROR));
            }
            $result[$table] = ['count' => count($hashes), 'primary_key' => $columns, 'rows' => $hashes];
        }
        ksort($result);

        return $result;
    }

    public function create(string $binary): string
    {
        self::assertLocal();
        $directory = base_path('../.tmp/sqs-ai/backups/'.now()->format('Ymd-His').'-'.bin2hex(random_bytes(3)));
        if (! mkdir($directory, 0700, true)) {
            throw new RuntimeException('Cannot create backup directory.');
        }
        $file = $directory.'/database.sql';
        $defaults = $directory.'/client.cnf';
        $quote = fn ($v) => '"'.str_replace(['\\', '"', "\n", "\r"], ['\\\\', '\\"', '\\n', '\\r'], (string) $v).'"';
        $cfg = DB::connection()->getConfig();
        file_put_contents($defaults, "[client]\nuser=".$quote($cfg['username'])."\npassword=".$quote($cfg['password'])."\n");
        @chmod($defaults, 0600);
        try {
            $before = $this->snapshot();
            $process = new Process([$binary, '--defaults-extra-file='.$defaults, '--host='.$cfg['host'],
                '--port='.($cfg['port'] ?? 3306), '--protocol=tcp', '--single-transaction', '--quick',
                '--skip-lock-tables', '--skip-extended-insert', '--complete-insert', '--hex-blob',
                '--routines', '--events', '--triggers', '--default-character-set=utf8mb4',
                '--result-file='.$file, DB::connection()->getDatabaseName()]);
            $process->setTimeout(120);
            $process->run();
            if (! $process->isSuccessful()) {
                throw new RuntimeException('mysqldump failed (exit '.$process->getExitCode().'); no insertion permitted.');
            }
            $after = $this->snapshot();
            if ($before !== $after) {
                throw new RuntimeException('Database changed during backup; retry while app activity is idle.');
            }
            $sql = file_get_contents($file);
            if (! str_contains($sql, '-- Dump completed on ')) {
                throw new RuntimeException('Backup has no completion footer.');
            }
            foreach ($before as $table => $data) {
                $escaped = preg_quote($table, '/');
                if (! preg_match('/CREATE TABLE `'.$escaped.'`/', $sql)
                    || preg_match_all('/^INSERT INTO `'.$escaped.'` /m', $sql) !== $data['count']) {
                    throw new RuntimeException('Backup schema/row-count verification failed for '.$table);
                }
            }
            $manifest = ['database' => DB::connection()->getDatabaseName(), 'created_at' => now()->toIso8601String(),
                'dump' => realpath($file), 'sha256' => hash_file('sha256', $file), 'bytes' => filesize($file),
                'verification' => 'Successful dump, completion footer, every table DDL and individual INSERT count, stable before/after row hashes. No restore rehearsal performed.',
                'tables' => $before];
            $path = $directory.'/manifest.json';
            file_put_contents($path, json_encode($manifest, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));

            return realpath($path);
        } finally {
            if (is_file($defaults)) {
                unlink($defaults);
            }
        }
    }

    public function verify(string $path): array
    {
        if (! is_file($path)) {
            throw new RuntimeException('A verified backup manifest is required. Run sqs:ai-backup first.');
        }
        $manifest = json_decode(file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        if (($manifest['database'] ?? null) !== DB::connection()->getDatabaseName()
            || ! is_file($manifest['dump'] ?? '')
            || ! hash_equals($manifest['sha256'], hash_file('sha256', $manifest['dump']))) {
            throw new RuntimeException('Backup database or SHA-256 verification failed.');
        }

        return $manifest;
    }

    public function preserved(array $before): array
    {
        $after = $this->snapshot();
        $changes = [];
        foreach ($before as $table => $data) {
            foreach ($data['rows'] as $key => $hash) {
                if (($after[$table]['rows'][$key] ?? null) !== $hash) {
                    $changes[] = ['table' => $table, 'key' => $key];
                }
            }
        }

        return $changes;
    }
}
