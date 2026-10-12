<?php

namespace App\Services;

use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class Clinic
{
    const ACTIVE = ['waiting', 'verified', 'assigned', 'called', 'in_consultation', 'skipped'];

    public static function roles(User $user, array $roles): void
    {
        abort_unless(in_array($user->role->role_name, $roles, true), 403, 'This action is not available for your role.');
    }

    public static function fail(string $message): never
    {
        throw ValidationException::withMessages(['request' => $message]);
    }

    public static function settings()
    {
        return DB::table('clinic_settings')->where('id', 1)->first();
    }

    public static function log(User $actor, string $action, string $type, ?int $id = null, ?string $details = null): void
    {
        DB::table('audit_logs')->insert(['actor_id' => $actor->user_id, 'action' => $action, 'record_type' => $type, 'record_id' => $id, 'details' => $details, 'created_at' => now()]);
    }

    public static function notify(int $userId, string $title, string $message, ?int $queueId = null): void
    {
        DB::table('notifications')->insert(['user_id' => $userId, 'queue_id' => $queueId, 'notification_title' => $title, 'notification_message' => $message, 'notification_status' => 'sent', 'sent_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
    }

    public static function validateQr(string $token): void
    {
        $settings = self::settings();
        if (! $settings->qr_token || ! hash_equals($settings->qr_token, $token) || ! $settings->qr_expires_at || now()->gte(Carbon::parse($settings->qr_expires_at))) {
            self::fail('This clinic QR code is invalid or expired. Please scan the latest code at reception.');
        }
        try {
            Crypt::decryptString($token);
        } catch (\Throwable $e) {
            self::fail('Invalid clinic QR code.');
        }
    }

    public static function queues(User $actor)
    {
        $query = DB::table('queues as q')->join('users as p', 'p.user_id', '=', 'q.user_id')
            ->join('departments as d', 'd.department_id', '=', 'q.department_id')
            ->leftJoin('rooms as r', 'r.room_id', '=', 'q.room_id')->leftJoin('users as doc', 'doc.user_id', '=', 'q.doctor_id')
            ->select('q.*', 'p.name as patient_name', 'p.user_identifier', 'd.department_name', 'r.room_name', 'doc.name as doctor_name');
        if ($actor->role->role_name === 'patient') {
            $query->where('q.user_id', $actor->user_id);
        }
        if ($actor->role->role_name === 'doctor') {
            $query->where('q.doctor_id', $actor->user_id);
        }

        return $query;
    }

    public static function ordered($query)
    {
        return $query->orderByDesc('q.priority')->orderBy('q.registered_at')->orderBy('q.queue_id');
    }

    public static function estimates($queues)
    {
        $settings = self::settings();
        $durations = DB::table('consultations as c')->join('queues as q', 'q.queue_id', '=', 'c.queue_id')
            ->where('c.consultation_status', 'completed')->whereNotNull('c.started_at')->whereNotNull('c.ended_at')
            ->orderByDesc('c.ended_at')->limit(500)->get(['q.department_id', 'q.doctor_id', 'q.queue_type', 'c.started_at', 'c.ended_at'])->reverse();
        $samples = [];
        foreach ($durations as $d) {
            $minutes = Carbon::parse($d->started_at)->diffInMinutes(Carbon::parse($d->ended_at), false);
            if ($minutes > 0 && $minutes < 240) {
                $samples[$d->department_id][] = [
                    'minutes' => $minutes, 'hour' => (int) Carbon::parse($d->started_at)->format('G'),
                    'doctor_id' => $d->doctor_id, 'queue_type' => $d->queue_type,
                ];
            }
        }
        $waiting = DB::table('queues')->whereIn('queue_status', self::ACTIVE)->orderByDesc('priority')->orderBy('registered_at')->orderBy('queue_id')->get();
        $roomCounts = DB::table('rooms')->where('status', 'available')->whereNotNull('doctor_id')->get()
            ->groupBy('department_id')->map(fn ($rooms) => $rooms->unique('doctor_id')->count());
        $predictions = [];

        return $queues->map(function ($q) use ($settings, $samples, $waiting, $roomCounts, &$predictions) {
            $ahead = $waiting->filter(fn ($w) => $w->department_id == $q->department_id && $w->queue_id != $q->queue_id &&
                ($w->priority > $q->priority || ($w->priority == $q->priority && ($w->registered_at < $q->registered_at || ($w->registered_at == $q->registered_at && $w->queue_id < $q->queue_id)))))->count();
            $data = $samples[$q->department_id] ?? [];
            $key = $q->department_id.':'.$q->doctor_id.':'.$q->queue_type;
            [$average, $method, $mae] = $predictions[$key] ??= QueueIntelligence::duration($data, $q, $settings->average_minutes);
            if ($q->doctor_id) {
                $ahead = $waiting->filter(fn ($w) => $w->doctor_id == $q->doctor_id && $w->queue_id != $q->queue_id &&
                    (in_array($w->queue_status, ['called', 'in_consultation']) ||
                     $w->priority > $q->priority || ($w->priority == $q->priority &&
                     ($w->registered_at < $q->registered_at || ($w->registered_at == $q->registered_at && $w->queue_id < $q->queue_id)))))->count();
            }
            $capacity = $q->doctor_id ? 1 : max(1, $roomCounts[$q->department_id] ?? 1);
            $q->people_ahead = in_array($q->queue_status, self::ACTIVE) ? $ahead : 0;
            $q->estimated_waiting_time = in_array($q->queue_status, ['waiting', 'verified', 'assigned', 'skipped']) ? (int) ceil($ahead * $average / $capacity) : 0;
            $q->estimate_method = $method;
            $q->model_samples = count($data);
            $q->validation_mae_minutes = $mae === null ? null : round($mae, 1);

            return $q;
        });
    }

    public static function approaching(int $departmentId): void
    {
        $next = DB::table('queues')->where('department_id', $departmentId)->whereIn('queue_status', ['verified', 'assigned'])
            ->orderByDesc('priority')->orderBy('registered_at')->limit(2)->get();
        foreach ($next as $q) {
            if (! DB::table('notifications')->where('queue_id', $q->queue_id)->where('notification_title', 'Your turn is approaching')->exists()) {
                self::notify($q->user_id,'Your turn is approaching','Please remain near your assigned consultation area.',$q->queue_id);
            }
        }
    }
}
