<?php

namespace App\Services;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ClinicNotifications
{
    public static function refresh(): void
    {
        DB::transaction(function () {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $appointments = DB::table('appointments')->where('appointment_status', 'confirmed')
                ->whereBetween('appointment_date', [now()->toDateString(), now()->addDay()->toDateString()])->get();
            foreach ($appointments as $a) {
                $at = Carbon::parse($a->appointment_date.' '.$a->appointment_time);
                if (! $at->isFuture() || now()->diffInHours($at) > 24) {
                    continue;
                }
                $message = 'Appointment #'.$a->appointment_id.' is on '.$at->format('d M Y, H:i').'. Scan the clinic QR code when you arrive.';
                if (! DB::table('notifications')->where('user_id', $a->user_id)->where('notification_title', 'Appointment reminder')->where('notification_message', $message)->exists()) {
                    Clinic::notify($a->user_id, 'Appointment reminder', $message);
                }
            }
            $queues = Clinic::estimates(DB::table('queues')->whereIn('queue_status', ['waiting', 'verified', 'assigned'])->get());
            foreach ($queues as $q) {
                $message = 'Queue '.$q->queue_number.': estimated wait approximately '.$q->estimated_waiting_time.' minutes. '.$q->estimate_method.'.';
                $last = DB::table('notifications')->where('queue_id', $q->queue_id)->where('notification_title', 'Waiting time update')->orderByDesc('notification_id')->first();
                if (! $last || ($last->notification_message !== $message && Carbon::parse($last->sent_at)->lte(now()->subMinutes(10)))) {
                    Clinic::notify($q->user_id, 'Waiting time update', $message, $q->queue_id);
                }
            }
        });
    }
}
