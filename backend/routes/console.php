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
