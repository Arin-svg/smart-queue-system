<?php

namespace App\Http\Controllers;

use App\Services\Clinic;
use App\Services\QueueIntelligence;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class WorkspaceController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        $role = $actor->role->role_name;
        $queues = Clinic::estimates(Clinic::queues($actor)->orderByDesc('q.registered_at')->limit(250)->get());
        $appointments = DB::table('appointments as a')->join('departments as d', 'd.department_id', '=', 'a.department_id')
            ->join('users as p', 'p.user_id', '=', 'a.user_id')->leftJoin('users as doc', 'doc.user_id', '=', 'a.doctor_id')
            ->select('a.*', 'd.department_name', 'p.name as patient_name', 'p.user_identifier', 'doc.name as doctor_name');
        if ($role === 'staff') {
            $appointments->orderByRaw("CASE WHEN a.appointment_status = 'pending' THEN 0 ELSE 1 END")->orderBy('appointment_date')->orderBy('appointment_time');
        }
        if ($role === 'patient') {
            $appointments->where('a.user_id', $actor->user_id);
        }
        if ($role === 'doctor') {
            $appointments->where('a.doctor_id', $actor->user_id);
        }
        $settings = (array) Clinic::settings();
        unset($settings['qr_token'],$settings['qr_expires_at']);
        $result = [
            'user' => $actor->profile(), 'queues' => $queues, 'appointments' => $appointments->orderByDesc('appointment_date')->limit(150)->get(),
            'departments' => DB::table('departments')->when($role !== 'administrator', fn ($q) => $q->where('status', 'active'))->orderBy('department_name')->get(),
            'rooms' => DB::table('rooms')->orderBy('room_name')->get(),
            'doctors' => DB::table('users as u')->join('roles as r', 'r.role_id', '=', 'u.role_id')->where('r.role_name', 'doctor')->where('u.status', 'active')->get(['u.user_id', 'u.name']),
            'notifications' => DB::table('notifications')->where('user_id', $actor->user_id)->orderByDesc('notification_id')->limit(100)->get(),
            'settings' => $settings, 'server_time' => now()->toIso8601String(),
        ];
        if (in_array($role, ['staff', 'administrator'])) {
            $result['patients'] = DB::table('users as u')->join('roles as r', 'r.role_id', '=', 'u.role_id')->where('r.role_name', 'patient')->where('u.status', 'active')->orderBy('u.name')->get(['u.user_id', 'u.name', 'u.user_identifier']);
        }
        if ($role === 'patient') {
            // Share aggregate activity only, never other patients' queue records.
            $counts = DB::table('queues')->whereIn('queue_status', Clinic::ACTIVE)
                ->selectRaw('queue_status, COUNT(*) as total')->groupBy('queue_status')->pluck('total', 'queue_status');
            $result['clinic_status'] = [
                'waiting' => collect(['waiting', 'verified', 'assigned', 'called', 'skipped'])->sum(fn ($status) => (int) ($counts[$status] ?? 0)),
                'in_consultation' => (int) ($counts['in_consultation'] ?? 0),
                'completed_today' => DB::table('queues')->where('queue_status', 'completed')->whereDate('completed_at', now()->toDateString())->count(),
                'updated_at' => now()->toIso8601String(),
            ];
        }
        if ($role === 'staff') {
            $samples = DB::table('priority_training_samples')->orderByDesc('created_at')->limit(500)->get()->all();
            foreach ($queues as $q) {
                if (in_array($q->queue_status, ['verified', 'assigned'])) {
                    $q->priority_recommendation = QueueIntelligence::priority($samples, $q);
                }
            }
        }
        if ($role === 'administrator') {
            $all = DB::table('queues')->get(['queue_status', 'registered_at', 'called_at']);
            $waits = $all->filter(fn ($q) => $q->called_at !== null)->map(fn ($q) => max(0, Carbon::parse($q->registered_at)->diffInMinutes(Carbon::parse($q->called_at), false)));
            $result['summary'] = ['total' => $all->count(), 'active' => $all->whereIn('queue_status', Clinic::ACTIVE)->count(),
                'completed' => $all->where('queue_status', 'completed')->count(),
                'average_wait_minutes' => $waits->count() ? round($waits->avg(), 1) : null,
                'users' => DB::table('users')->count(), 'active_departments' => DB::table('departments')->where('status', 'active')->count()];
            $result['users'] = DB::table('users as u')->join('roles as r', 'r.role_id', '=', 'u.role_id')->orderBy('u.name')->get(['u.user_id', 'u.role_id', 'u.name', 'u.email', 'u.phone_no', 'u.user_identifier', 'u.status', 'r.role_name']);
            $result['roles'] = DB::table('roles')->get();
            $result['logs'] = DB::table('audit_logs as l')->leftJoin('users as u', 'u.user_id', '=', 'l.actor_id')->orderByDesc('l.id')->limit(100)->get(['l.*', 'u.name as actor_name']);
        }

        return response()->json($result);
    }

    public function readNotification(Request $request, int $id)
    {
        $count = DB::table('notifications')->where('notification_id', $id)->where('user_id', $request->user()->user_id)
            ->update(['notification_status' => 'read', 'read_at' => now(), 'updated_at' => now()]);
        abort_unless($count,404);

        return ['message' => 'Notification marked as read.'];
    }

    public function readNotifications(Request $request)
    {
        $data = $request->validate(['ids' => 'required|array|max:100', 'ids.*' => 'integer']);
        DB::table('notifications')->where('user_id', $request->user()->user_id)
            ->whereIn('notification_id', $data['ids'])->where('notification_status', '!=', 'read')
            ->update(['notification_status' => 'read', 'read_at' => now(), 'updated_at' => now()]);
        return ['message' => 'Notifications marked as read.'];
    }
}
