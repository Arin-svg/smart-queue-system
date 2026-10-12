<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\Clinic;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class QueueController extends Controller
{
    public function qr(Request $request)
    {
        Clinic::roles($request->user(), ['staff', 'administrator']);

        return ['token' => Clinic::settings()->qr_token, 'expires_at' => null];
    }

    public function replaceQr(Request $request)
    {
        Clinic::roles($request->user(), ['administrator']);

        return DB::transaction(function () use ($request) {
            $settings = DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $token = Crypt::encryptString(Str::random(32));
            DB::table('clinic_settings')->where('id', 1)->update(['qr_token' => $token, 'qr_expires_at' => null]);
            Clinic::log($request->user(), $settings->qr_token ? 'replace_qr' : 'create_qr', 'clinic');

            return [
                'token' => $token,
                'expires_at' => null,
                'message' => $settings->qr_token ? 'Clinic QR code replaced. Previous copies no longer work.' : 'Clinic QR code created.',
            ];
        }, 3);
    }

    public function validateQr(Request $request)
    {
        Clinic::roles($request->user(), ['patient']);
        $data = $request->validate(['qr_token' => 'required|string|max:2000']);
        Clinic::validateQr($data['qr_token']);

        return ['message' => 'Clinic QR code verified.'];
    }

    public function store(Request $request)
    {
        $actor = $request->user();
        Clinic::roles($actor, ['patient', 'staff']);
        $data = $request->validate(['department_id' => 'required|integer|exists:departments,department_id',
            'reason_for_visit' => 'required|string|max:255', 'qr_token' => 'nullable|string|max:2000',
            'user_id' => 'nullable|integer|exists:users,user_id', 'appointment_id' => 'nullable|integer|exists:appointments,appointment_id']);

        return DB::transaction(function () use ($actor, $data) {
            $settings = DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            if (! $settings->registration_open) {
                Clinic::fail('Queue registration is currently closed.');
            }
            if ($actor->role->role_name === 'patient') {
                Clinic::validateQr($data['qr_token'] ?? '');
            }
            $patientId = $actor->role->role_name === 'patient' ? $actor->user_id : ($data['user_id'] ?? 0);
            $patient = User::with('role')->find($patientId);
            if (! $patient || $patient->role->role_name !== 'patient' || $patient->status !== 'active') {
                Clinic::fail('Select an active patient account.');
            }
            if (DB::table('queues')->where('user_id', $patientId)->whereIn('queue_status', Clinic::ACTIVE)->exists()) {
                Clinic::fail('This patient already has an active queue.');
            }
            $dept = DB::table('departments')->where('department_id', $data['department_id'])->where('status', 'active')->first();
            if (! $dept) {
                Clinic::fail('This department is not available.');
            }
            $appointment = null;
            if (! empty($data['appointment_id'])) {
                $appointment = DB::table('appointments')->where('appointment_id', $data['appointment_id'])->first();
                if ($appointment->user_id != $patientId || $appointment->department_id != $dept->department_id ||
                    $appointment->appointment_status !== 'confirmed' || $appointment->appointment_date !== now()->toDateString()) {
                    Clinic::fail('Only your staff-confirmed appointment for today can be checked in.');
                }
                if (DB::table('queues')->where('appointment_id', $appointment->appointment_id)->exists()) {
                    Clinic::fail('This appointment has already been checked in.');
                }
            }
            $id = DB::table('queues')->insertGetId([
                'user_id' => $patientId, 'department_id' => $dept->department_id, 'appointment_id' => $appointment?->appointment_id,
                'queue_number' => strtoupper(bin2hex(random_bytes(8))), 'queue_type' => $appointment ? 'appointment' : 'qr_walk_in',
                'queue_status' => 'waiting', 'reason_for_visit' => $data['reason_for_visit'], 'registered_at' => now(), 'priority' => 0,
                'created_at' => now(), 'updated_at' => now(),
            ], 'queue_id');
            $number = now()->format('ymd').'-'.str_pad((string) $id, 5, '0', STR_PAD_LEFT);
            DB::table('queues')->where('queue_id', $id)->update(['queue_number' => $number]);
            Clinic::notify($patientId, 'Queue registered', 'Your queue number is '.$number.'. Please wait for registration verification.', $id);
            Clinic::log($actor, 'register_queue', 'queue', $id);

            return response()->json(['message' => 'Queue registered.', 'queue_id' => $id, 'queue_number' => $number], 201);
        }, 3);
    }

    public function update(Request $request, int $id)
    {
        $actor = $request->user();
        $data = $request->validate(['action' => 'required|in:verify,assign,priority,call,start,complete,skip,absent,requeue,cancel',
            'doctor_id' => 'nullable|integer|exists:users,user_id', 'room_id' => 'nullable|integer|exists:rooms,room_id',
            'priority' => 'nullable|integer|min:0|max:2', 'priority_note' => 'nullable|string|max:255']);

        return DB::transaction(function () use ($actor, $data, $id) {
            DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            $q = DB::table('queues')->where('queue_id', $id)->lockForUpdate()->first();
            abort_unless($q, 404);
            $action = $data['action'];
            $change = ['updated_at' => now()];
            if (in_array($action, ['verify', 'assign', 'priority', 'requeue'])) {
                Clinic::roles($actor, ['staff']);
            } elseif ($action === 'cancel') {
                Clinic::roles($actor, ['patient', 'staff']);
                if ($actor->role->role_name === 'patient') {
                    abort_unless($q->user_id === $actor->user_id, 403);
                }
            } else {
                Clinic::roles($actor, ['doctor']);
                abort_unless($q->doctor_id === $actor->user_id, 403);
            }
            $allowed = [
                'verify' => ['waiting'], 'assign' => ['verified', 'assigned'], 'priority' => ['verified', 'assigned', 'skipped'],
                'call' => ['assigned'], 'start' => ['called'], 'complete' => ['in_consultation'],
                'skip' => ['called'], 'absent' => ['called'], 'requeue' => ['skipped'], 'cancel' => ['waiting', 'verified', 'assigned', 'skipped'],
            ];
            if (! in_array($q->queue_status, $allowed[$action])) {
                Clinic::fail('This queue status has changed. Refresh and try again.');
            }
            if ($action === 'verify') {
                $change += ['queue_status' => 'verified', 'verified_by' => $actor->user_id, 'verified_at' => now()];
            }
            if ($action === 'assign') {
                $room = DB::table('rooms')->where('room_id', $data['room_id'] ?? 0)->first();
                $doc = User::with('role')->find($data['doctor_id'] ?? 0);
                if (! $room || $room->status !== 'available' || $room->department_id !== $q->department_id ||
                    ! $doc || $doc->role->role_name !== 'doctor' || $doc->status !== 'active' || $room->doctor_id !== $doc->user_id) {
                    Clinic::fail('Choose an available room and its assigned doctor in this department.');
                }
                $change += ['queue_status' => 'assigned', 'doctor_id' => $doc->user_id, 'room_id' => $room->room_id];
            }
            if ($action === 'priority') {
                if (! isset($data['priority']) || empty(trim($data['priority_note'] ?? ''))) {
                    Clinic::fail('Select a priority and record the staff decision reason.');
                }
                $change += ['priority' => $data['priority'], 'priority_note' => $data['priority_note']];
                DB::table('priority_training_samples')->updateOrInsert(['queue_id' => $id], [
                    'department_id' => $q->department_id, 'reason_for_visit' => $q->reason_for_visit,
                    'queue_type' => $q->queue_type,
                    'wait_minutes' => (int) max(0, Carbon::parse($q->registered_at)->diffInMinutes(now(), false)),
                    'priority' => $data['priority'], 'reviewed_by' => $actor->user_id, 'created_at' => now(),
                ]);
            }
            if ($action === 'requeue') {
                $change += ['queue_status' => 'assigned', 'registered_at' => now()];
            }
            if ($action === 'call') {
                $room = DB::table('rooms')->where('room_id', $q->room_id)->first();
                if (! $room || $room->status !== 'available' || $room->doctor_id !== $actor->user_id) {
                    Clinic::fail('The assigned room is no longer available.');
                }
                if (DB::table('queues')->whereIn('queue_status', ['called', 'in_consultation'])->where(fn ($b) => $b->where('doctor_id', $actor->user_id)->orWhere('room_id', $q->room_id))->exists()) {
                    Clinic::fail('Finish the current patient before calling another.');
                }
                $next = DB::table('queues')->where('doctor_id', $actor->user_id)->where('queue_status', 'assigned')->orderByDesc('priority')->orderBy('registered_at')->orderBy('queue_id')->first();
                if ($next?->queue_id !== $id) {
                    Clinic::fail('Call the next patient in the approved queue order.');
                }
                $change += ['queue_status' => 'called', 'called_at' => now()];
                DB::table('consultations')->updateOrInsert(['queue_id' => $id], [
                    'user_id' => $actor->user_id, 'room_id' => $q->room_id, 'consultation_status' => 'called',
                    'started_at' => null, 'ended_at' => null, 'created_at' => now(), 'updated_at' => now(),
                ]);
            }
            if ($action === 'start') {
                $change += ['queue_status' => 'in_consultation'];
            }
            if ($action === 'complete') {
                $change += ['queue_status' => 'completed', 'completed_at' => now()];
            }
            if ($action === 'skip') {
                $change += ['queue_status' => 'skipped'];
            }
            if ($action === 'absent') {
                $change += ['queue_status' => 'absent', 'completed_at' => now()];
            }
            if ($action === 'cancel') {
                $change += ['queue_status' => 'cancelled', 'completed_at' => now()];
            }
            DB::table('queues')->where('queue_id', $id)->update($change);
            if (in_array($action, ['start', 'complete', 'skip', 'absent'])) {
                $consult = ['consultation_status' => $change['queue_status'], 'updated_at' => now()];
                if ($action === 'start') {
                    $consult['started_at'] = now();
                }
                if (in_array($action, ['complete', 'absent', 'skip'])) {
                    $consult['ended_at'] = now();
                }
                DB::table('consultations')->where('queue_id', $id)->update($consult);
            }
            if ($q->appointment_id && in_array($action, ['complete', 'absent', 'cancel'])) {
                DB::table('appointments')->where('appointment_id', $q->appointment_id)->update(['appointment_status' => ['complete' => 'completed', 'absent' => 'absent', 'cancel' => 'cancelled'][$action], 'updated_at' => now()]);
            }
            $status = $change['queue_status'] ?? $q->queue_status;
            $message = $q->queue_number.': '.str_replace('_', ' ', $status).'.';
            if ($action === 'call') {
                $message .= ' Please proceed to '.$room->room_name.'.';
            }
            Clinic::notify($q->user_id, $action === 'call' ? 'Your turn has been called' : 'Queue updated', $message, $id);
            Clinic::log($actor,$action,'queue',$id,$data['priority_note'] ?? null);
            Clinic::approaching($q->department_id);

            return ['message' => 'Queue updated.'];
        }, 3);
    }
}
