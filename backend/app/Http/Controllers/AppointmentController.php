<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\Clinic;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AppointmentController extends Controller
{
    public function slots(Request $request)
    {
        Clinic::roles($request->user(), ['patient', 'staff']);
        $data = $request->validate(['department_id' => 'required|integer|exists:departments,department_id', 'date' => 'required|date_format:Y-m-d|after_or_equal:today', 'doctor_id' => 'nullable|integer|exists:users,user_id']);
        if (! DB::table('departments')->where('department_id', $data['department_id'])->where('status', 'active')->exists()) {
            Clinic::fail('Department unavailable.');
        }
        if (! empty($data['doctor_id']) && ! DB::table('rooms')->where('department_id', $data['department_id'])->where('doctor_id', $data['doctor_id'])->where('status', 'available')->exists()) {
            Clinic::fail('Doctor unavailable for this department.');
        }
        $settings = Clinic::settings();
        $start = Carbon::parse($data['date'].' '.$settings->opening_time);
        $end = Carbon::parse($data['date'].' '.$settings->closing_time);
        $slots = [];
        if ($start->isWeekend()) {
            return ['slots' => []];
        }
        for ($at = $start->copy(); $at->copy()->addMinutes($settings->slot_minutes)->lte($end); $at->addMinutes($settings->slot_minutes)) {
            $taken = DB::table('appointments')->where('department_id', $data['department_id'])->whereDate('appointment_date', $data['date'])
                ->where('appointment_time', $at->format('H:i:s'))->whereIn('appointment_status', ['pending', 'confirmed']);
            $count = (clone $taken)->count();
            $doctorTaken = ! empty($data['doctor_id']) && DB::table('appointments')->where('doctor_id', $data['doctor_id'])->whereDate('appointment_date', $data['date'])->where('appointment_time', $at->format('H:i:s'))->whereIn('appointment_status', ['pending', 'confirmed'])->exists();
            $patientTaken = $request->user()->role->role_name === 'patient' && DB::table('appointments')->where('user_id', $request->user()->user_id)->whereDate('appointment_date', $data['date'])->where('appointment_time', $at->format('H:i:s'))->whereIn('appointment_status', ['pending', 'confirmed'])->exists();
            if ($at->isFuture() && $count < $settings->slot_capacity && ! $doctorTaken && ! $patientTaken) {
                $slots[] = $at->format('H:i');
            }
        }

        return ['slots' => $slots];
    }

    public function store(Request $request)
    {
        $actor = $request->user();
        Clinic::roles($actor, ['patient']);
        $data = $request->validate(['department_id' => 'required|integer|exists:departments,department_id', 'doctor_id' => 'nullable|integer|exists:users,user_id',
            'appointment_date' => 'required|date_format:Y-m-d|after_or_equal:today', 'appointment_time' => 'required|date_format:H:i', 'reason_for_visit' => 'required|string|max:255']);

        return DB::transaction(function () use ($actor, $data) {
            $s = DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            if (! DB::table('departments')->where('department_id', $data['department_id'])->where('status', 'active')->exists()) {
                Clinic::fail('Department unavailable.');
            }
            $at = Carbon::parse($data['appointment_date'].' '.$data['appointment_time']);
            $open = Carbon::parse($data['appointment_date'].' '.$s->opening_time);
            $close = Carbon::parse($data['appointment_date'].' '.$s->closing_time);
            if (! $at->isFuture() || $at->isWeekend() || $at->lt($open) || $at->copy()->addMinutes($s->slot_minutes)->gt($close) || (int) $open->diffInMinutes($at) % $s->slot_minutes !== 0) {
                Clinic::fail('Choose a valid available weekday slot.');
            }
            if (! empty($data['doctor_id'])) {
                $doctor = User::with('role')->find($data['doctor_id']);
                if ($doctor->status !== 'active' || $doctor->role->role_name !== 'doctor' || ! DB::table('rooms')->where('department_id', $data['department_id'])->where('doctor_id', $doctor->user_id)->where('status', 'available')->exists()) {
                    Clinic::fail('Doctor unavailable for this department.');
                }
            }
            $bookings = DB::table('appointments')->whereDate('appointment_date', $data['appointment_date'])->where('appointment_time', $data['appointment_time'].':00')->whereIn('appointment_status', ['pending', 'confirmed']);
            if ((clone $bookings)->where('department_id', $data['department_id'])->count() >= $s->slot_capacity ||
                (clone $bookings)->where('user_id', $actor->user_id)->exists() ||
                (! empty($data['doctor_id']) && (clone $bookings)->where('doctor_id', $data['doctor_id'])->exists())) {
                Clinic::fail('This time slot is no longer available.');
            }
            $data['appointment_time'] = $at->format('H:i:s');
            $id = DB::table('appointments')->insertGetId($data + ['user_id' => $actor->user_id, 'appointment_status' => 'pending', 'created_at' => now(), 'updated_at' => now()], 'appointment_id');
            Clinic::notify($actor->user_id, 'Appointment awaiting verification', 'Your appointment request for '.$at->format('d M Y, H:i').' is pending staff verification.');
            Clinic::notifyVerificationStaff('A new appointment request is waiting for verification. Open Verify to review.');
            Clinic::log($actor, 'book_appointment', 'appointment', $id);

            return response()->json(['message' => 'Appointment requested. Awaiting staff verification.', 'appointment_id' => $id, 'appointment_status' => 'pending'], 201);
        }, 3);
    }

    public function verify(Request $request, int $id)
    {
        $actor = $request->user();
        Clinic::roles($actor, ['staff']);

        return DB::transaction(function () use ($actor, $id) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $appointment = DB::table('appointments')->where('appointment_id', $id)->lockForUpdate()->first();
            abort_unless($appointment, 404);
            if ($appointment->appointment_status !== 'pending') {
                Clinic::fail('Only pending appointments can be verified.');
            }
            $at = Carbon::parse($appointment->appointment_date.' '.$appointment->appointment_time);
            if (! $at->isFuture()) {
                Clinic::fail('This appointment time has passed. The patient must book a new time.');
            }
            if (! DB::table('departments')->where('department_id', $appointment->department_id)->where('status', 'active')->exists()) {
                Clinic::fail('Department unavailable.');
            }
            if ($appointment->doctor_id) {
                $doctor = User::with('role')->find($appointment->doctor_id);
                if (! $doctor || $doctor->status !== 'active' || $doctor->role->role_name !== 'doctor' || ! DB::table('rooms')->where('department_id', $appointment->department_id)->where('doctor_id', $appointment->doctor_id)->where('status', 'available')->exists()) {
                    Clinic::fail('Doctor unavailable for this department.');
                }
            }
            DB::table('appointments')->where('appointment_id', $id)->update(['appointment_status' => 'confirmed', 'updated_at' => now()]);
            Clinic::log($actor, 'verify_appointment', 'appointment', $id);
            Clinic::notify($appointment->user_id, 'Appointment confirmed', 'Staff have verified your appointment on '.$at->format('d M Y, H:i').'. Scan the clinic QR code when you arrive.');

            return ['message' => 'Appointment verified and confirmed.', 'appointment_id' => $id, 'appointment_status' => 'confirmed'];
        }, 3);
    }

    public function cancel(Request $request, int $id)
    {
        Clinic::roles($request->user(), ['patient']);

        return DB::transaction(function () use ($request, $id) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $a = DB::table('appointments')->where('appointment_id', $id)->where('user_id', $request->user()->user_id)->first();
            abort_unless($a, 404);
            if (! in_array($a->appointment_status, ['pending', 'confirmed'])) {
                Clinic::fail('This appointment cannot be cancelled.');
            }
            if (DB::table('queues')->where('appointment_id', $id)->whereIn('queue_status', Clinic::ACTIVE)->exists()) {
                Clinic::fail('Cancel the active queue first.');
            }
            DB::table('appointments')->where('appointment_id', $id)->update(['appointment_status' => 'cancelled', 'updated_at' => now()]);
            Clinic::notify($a->user_id, 'Appointment cancelled', 'Your appointment on '.$a->appointment_date.' has been cancelled.');
            Clinic::log($request->user(),'cancel_appointment','appointment',$id);

            return ['message' => 'Appointment cancelled.'];
        });
    }
}
