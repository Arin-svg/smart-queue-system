<?php

namespace App\Http\Controllers;

use App\Services\Clinic;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function index(Request $request)
    {
        Clinic::roles($request->user(), ['administrator']);
        $data = $request->validate(['start' => 'required|date_format:Y-m-d', 'end' => 'required|date_format:Y-m-d|after_or_equal:start', 'department_id' => 'nullable|integer|exists:departments,department_id']);
        if (Carbon::parse($data['start'])->diffInDays(Carbon::parse($data['end'])) > 366) {
            Clinic::fail('Select a date range of one year or less.');
        }
        $rows = DB::table('queues as q')->join('departments as d', 'd.department_id', '=', 'q.department_id')
            ->whereBetween('registered_at', [$data['start'].' 00:00:00', $data['end'].' 23:59:59'])
            ->when(! empty($data['department_id']), fn ($q) => $q->where('q.department_id', $data['department_id']))
            ->get(['q.*', 'd.department_name']);
        $waits = $rows->filter(fn ($r) => $r->called_at !== null)->map(fn ($r) => max(0, Carbon::parse($r->registered_at)->diffInMinutes(Carbon::parse($r->called_at), false)));

        return ['start' => $data['start'], 'end' => $data['end'], 'total' => $rows->count(),
            'active' => $rows->whereIn('queue_status', Clinic::ACTIVE)->count(), 'completed' => $rows->where('queue_status', 'completed')->count(),
            'average_wait_minutes' => $waits->count() ? round($waits->avg(), 1) : null,
            'departments' => $rows->groupBy('department_name')->map(fn ($group, $name) => ['name' => $name, 'count' => $group->count()])->values(),
            'users' => DB::table('users')->count(), 'active_departments' => DB::table('departments')->where('status', 'active')->count()];
    }
}
