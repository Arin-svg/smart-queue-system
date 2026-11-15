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

    public static function mailPaused(): bool
    {
        return self::paused() && ! is_file(self::path().'-mail-resumed');
    }

    public static function allowMail(\Illuminate\Mail\Events\MessageSending $event): ?bool
    {
        foreach (array_merge($event->message->getTo(), $event->message->getCc(), $event->message->getBcc()) as $recipient) {
            if (str_ends_with(strtolower($recipient->getAddress()), '@example.invalid')) {
                return false;
            }
        }

        return self::mailPaused() ? false : null;
    }

    public static function pause(): void
    {
        DevelopmentDatabaseBackup::assertLocal();
        if (is_file(self::path().'-mail-resumed')) {
            unlink(self::path().'-mail-resumed');
        }
        if (! is_dir(dirname(self::path()))) {
            mkdir(dirname(self::path()), 0700, true);
        }
        if (file_put_contents(self::path(), 'Synthetic AI evaluation: local mail, push and scheduled alert generation paused.') === false) {
            throw new \RuntimeException('Cannot establish notification safety pause.');
        }
    }
}
