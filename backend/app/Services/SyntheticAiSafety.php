<?php

namespace App\Services;

class SyntheticAiSafety
{
    public static function path(): string
    {
        return base_path('../.tmp/sqs-ai/outbound-paused');
    }

    public static function paused(): bool
    {
        return app()->environment('local') && is_file(self::path());
    }

    public static function pause(): void
    {
        DevelopmentDatabaseBackup::assertLocal();
        if (! is_dir(dirname(self::path()))) {
            mkdir(dirname(self::path()), 0700, true);
        }
        if (file_put_contents(self::path(), 'Synthetic AI evaluation: local mail, push and scheduled alert generation paused.') === false) {
            throw new \RuntimeException('Cannot establish notification safety pause.');
        }
    }
}
