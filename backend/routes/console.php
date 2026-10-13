<?php

use App\Services\ClinicNotifications;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('sqs:notifications', function () {
    ClinicNotifications::refresh();
    $this->info('Queue updates and appointment reminders refreshed.');
})->purpose('Generate patient queue updates and appointment reminders');

Schedule::command('sqs:notifications')->everyMinute()->withoutOverlapping();

Artisan::command('sqs:push', function () {
    try {
        $sent = app(\App\Services\FirebasePush::class)->deliver();
        $this->info("Delivered {$sent} device notifications.");
    } catch (\Throwable $e) {
        $this->error('Push delivery failed. Check Firebase credentials, connectivity and API access.');
        return 1;
    }
})->purpose('Deliver new clinic alerts to registered devices');
Schedule::command('sqs:push')->everyTenSeconds()->withoutOverlapping();
