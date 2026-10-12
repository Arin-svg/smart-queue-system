<?php

use App\Services\Clinic;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Imported appointments have no application booking audit and are left intact.
        if (! Schema::hasTable('appointments')) {
            return;
        }
        DB::transaction(function () {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $appointments = DB::table('appointments')
                ->where('appointment_status', 'confirmed')
                ->where(function ($query) {
                    $query->where('appointment_date', '>', now()->toDateString())
                        ->orWhere(function ($today) {
                            $today->where('appointment_date', now()->toDateString())->where('appointment_time', '>', now()->format('H:i:s'));
                        });
                })
                ->whereExists(function ($query) {
                    $query->selectRaw('1')->from('audit_logs')->where('action', 'book_appointment')->where('record_type', 'appointment')
                        ->whereColumn('record_id', 'appointments.appointment_id')->whereColumn('actor_id', 'appointments.user_id');
                })
                ->whereNotExists(function ($query) {
                    $query->selectRaw('1')->from('audit_logs')->where('action', 'verify_appointment')->where('record_type', 'appointment')
                        ->whereColumn('record_id', 'appointments.appointment_id');
                })
                ->whereNotExists(function ($query) {
                    $query->selectRaw('1')->from('queues')->whereColumn('queues.appointment_id', 'appointments.appointment_id');
                })->get();
            foreach ($appointments as $appointment) {
                DB::table('appointments')->where('appointment_id', $appointment->appointment_id)
                    ->update(['appointment_status' => 'pending', 'updated_at' => now()]);
                Clinic::notify($appointment->user_id, 'Appointment awaiting verification',
                    'Your appointment on '.$appointment->appointment_date.' at '.$appointment->appointment_time.' now awaits staff verification. Your time slot remains reserved.');
                DB::table('audit_logs')->insert(['actor_id' => null, 'action' => 'require_appointment_verification',
                    'record_type' => 'appointment', 'record_id' => $appointment->appointment_id,
                    'details' => 'Previously auto-confirmed booking returned to pending for staff verification.', 'created_at' => now()]);
            }
        });
    }

    public function down(): void
    {
        // Do not confirm appointments without a staff decision when rolling back.
    }
};
