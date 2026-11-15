<?php

namespace App\Services;

use App\Http\Controllers\ReportController;
use App\Http\Controllers\WorkspaceController;
use App\Models\User;
use Carbon\Carbon;
use Database\Seeders\SyntheticAiDatasetSeeder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use ReflectionMethod;
use RuntimeException;

class SyntheticAiEvaluation
{
    /** Diagnostics call the ORIGINAL private regression routine, not a reimplementation. */
    public static function durationMetrics(array $samples, float $fallback): array
    {
        $split = (int) floor(count($samples) * .8);
        $train = array_slice($samples, 0, $split);
        $validation = array_slice($samples, $split);
        if (count($samples) < 20) {
            [$prediction, $method, $mae] = QueueIntelligence::duration($samples, (object) [], $fallback);
            return ['samples' => count($samples), 'method' => $method, 'prediction' => $prediction, 'selected_mae' => $mae];
        }
        $mean = array_sum(array_column($train, 'minutes')) / count($train);
        $baseline = array_sum(array_map(fn ($s) => abs($mean - $s['minutes']), $validation)) / count($validation);
        $regress = new ReflectionMethod(QueueIntelligence::class, 'regress');
        $errors = [];
        foreach ([3, 5, 7] as $k) {
            $errors[$k] = array_sum(array_map(fn ($s) => abs($regress->invoke(null, $train, $s, $k) - $s['minutes']), $validation)) / count($validation);
        }
        $best = array_search(min($errors), $errors, true);
        [, $method, $mae] = QueueIntelligence::duration($samples, (object) [], $fallback);
        $selectedK = $errors[$best] < $baseline ? $best : null;
        $expected = round($selectedK === null ? $baseline : $errors[$best], 2);
        if (abs($mae - $expected) > .001 || (($selectedK !== null) !== str_starts_with($method, 'KNN'))) {
            throw new RuntimeException('Diagnostics disagree with the production duration service.');
        }
        return ['samples' => count($samples), 'train' => count($train), 'validation' => count($validation),
            'best_candidate_k' => $best, 'selected_k' => $selectedK, 'knn_mae_by_k' => array_map(fn ($v) => round($v, 4), $errors),
            'baseline_mae' => round($baseline, 4), 'selected_mae' => $mae, 'method' => $method,
            'training_end' => end($train)['ended_at'], 'validation_start' => $validation[0]['ended_at']];
    }

    private static function durationSamples($rows): array
    {
        return $rows->filter(fn ($r) => $r->started_at && $r->ended_at)->map(function ($r) {
            return ['minutes' => Carbon::parse($r->started_at)->diffInMinutes(Carbon::parse($r->ended_at), false),
                'hour' => (int) Carbon::parse($r->started_at)->format('G'), 'doctor_id' => $r->doctor_id,
                'queue_type' => $r->queue_type, 'started_at' => $r->started_at, 'ended_at' => $r->ended_at];
        })->filter(fn ($s) => $s['minutes'] > 0 && $s['minutes'] < 240)->values()->all();
    }

    public function run(): array
    {
        DevelopmentDatabaseBackup::assertLocal();
        $receipt = SyntheticAiDatasetSeeder::receipt();
        if (! $receipt) throw new RuntimeException('Seed receipt not found.');
        if (! hash_equals($receipt['fingerprint'], SyntheticAiDatasetSeeder::fingerprint($receipt['ids']))) {
            throw new RuntimeException('Synthetic records changed since insertion; evaluate the unchanged snapshot before functional manual edits.');
        }
        $oldNow = Carbon::getTestNow();
        Carbon::setTestNow(Carbon::parse($receipt['as_of']));
        try {
            $fallback = (float) Clinic::settings()->average_minutes;
            $all = DB::table('consultations as c')->join('queues as q', 'q.queue_id', '=', 'c.queue_id')
                ->where('c.consultation_status', 'completed')->whereNotNull('c.started_at')->whereNotNull('c.ended_at')
                ->orderBy('c.ended_at')->orderBy('c.consultation_id')
                ->get(['c.*', 'q.department_id', 'q.doctor_id', 'q.queue_type', 'q.registered_at', 'q.called_at', 'q.completed_at', 'q.queue_status']);
            $synthetic = $all->whereIn('queue_id', $receipt['ids']['queues']);
            $duration = [];
            foreach ($receipt['departments'] as $department => $name) {
                $samples = self::durationSamples($synthetic->where('department_id', $department));
                $metrics = self::durationMetrics($samples, $fallback);
                $dev = array_slice($samples, 0, (int) floor(count($samples) * .8));
                $test = array_slice($samples, count($dev));
                $development = self::durationMetrics($dev, $fallback);
                $errors = [];
                foreach ($test as $sample) {
                    Carbon::setTestNow(Carbon::parse($sample['started_at']));
                    [$prediction] = QueueIntelligence::duration($dev, (object) $sample, $fallback);
                    $errors[] = abs($prediction - $sample['minutes']);
                }
                Carbon::setTestNow(Carbon::parse($receipt['as_of']));
                $metrics['independent_chronological_test'] = ['development' => count($dev), 'inner_train' => $development['train'],
                    'inner_validation' => $development['validation'], 'test' => count($test), 'selected_k' => $development['selected_k'],
                    'method' => $development['method'], 'mae' => round(array_sum($errors) / count($errors), 4),
                    'note' => 'Test targets never enter model selection for this evaluation; production still sees all inserted records.'];
                $metrics['fewer_than_20_fallback'] = self::durationMetrics(array_slice($samples, 0, 19), $fallback);
                $metrics['runtime_combined_latest_500'] = self::durationMetrics(self::durationSamples($all->take(-500)->where('department_id', $department)), $fallback);
                $duration[$name] = $metrics;
            }
            $priority = $this->priority($receipt);
            Carbon::setTestNow(Carbon::parse($receipt['as_of']));
            $active = DB::table('queues')->whereIn('queue_status', Clinic::ACTIVE)->orderBy('queue_id')->get();
            $orderBefore = DB::table('queues')->orderByDesc('priority')->orderBy('registered_at')->orderBy('queue_id')->pluck('queue_id')->all();
            $estimates = Clinic::estimates($active)->map(fn ($q) => ['queue_id' => $q->queue_id,
                'synthetic' => in_array($q->queue_id, $receipt['ids']['queues']), 'department_id' => $q->department_id,
                'status' => $q->queue_status, 'doctor_id' => $q->doctor_id, 'priority' => $q->priority,
                'people_ahead' => $q->people_ahead, 'wait_minutes' => $q->estimated_waiting_time, 'method' => $q->estimate_method])->all();
            $samples = DB::table('priority_training_samples')->orderByDesc('created_at')->limit(500)->get()->all();
            $recommendations = [];
            foreach ($active as $queue) {
                if (in_array($queue->queue_status, ['verified', 'assigned'])) {
                    $recommendations[] = ['queue_id' => $queue->queue_id, 'result' => QueueIntelligence::priority($samples, $queue)];
                }
            }
            $orderAfter = DB::table('queues')->orderByDesc('priority')->orderBy('registered_at')->orderBy('queue_id')->pluck('queue_id')->all();
            $checks = $this->integrity($receipt, $synthetic);
            $reports = $this->reports($receipt);
            $outliers = $all->whereNotIn('queue_id', $receipt['ids']['queues'])->filter(fn ($q) => Carbon::parse($q->registered_at)->diffInMinutes(Carbon::parse($q->called_at), false) > 240)
                ->map(fn ($q) => ['queue_id' => $q->queue_id, 'registered_at' => $q->registered_at, 'called_at' => $q->called_at,
                    'recorded_wait_minutes' => round(Carbon::parse($q->registered_at)->diffInMinutes(Carbon::parse($q->called_at), false), 2)])->values()->all();
            return ['dataset' => 'SYNTHETIC DEVELOPMENT DATA — not clinical performance', 'as_of' => $receipt['as_of'],
                'seed' => $receipt['seed'], 'counts' => $receipt['counts'], 'duration' => $duration, 'priority' => $priority,
                'integrity' => $checks, 'workload' => $estimates, 'live_priority_recommendations' => $recommendations,
                'queue_order_unchanged' => $orderBefore === $orderAfter,
                'synthetic_fingerprint_unchanged' => hash_equals($receipt['fingerprint'], SyntheticAiDatasetSeeder::fingerprint($receipt['ids'])),
                'reports' => $reports, 'preserved_old_wait_outliers' => $outliers,
                'outbound_paused' => SyntheticAiSafety::paused(), 'backup_manifest' => $receipt['backup_manifest'],
                'production_algorithms_unchanged' => $receipt['source_hashes'] === ['QueueIntelligence' => hash_file('sha256', app_path('Services/QueueIntelligence.php')), 'Clinic' => hash_file('sha256', app_path('Services/Clinic.php'))],
                'limitation' => 'The main 80/20 validation holdout selects k and baseline; it is not independent final test accuracy. Synthetic labels are not clinical urgency assessments.'];
        } finally {
            Carbon::setTestNow($oldNow);
        }
    }

    private function priority(array $receipt): array
    {
        $rows = DB::table('priority_training_samples')->whereIn('id', $receipt['ids']['priority_training_samples'])->orderBy('created_at')->orderBy('id')->get();
        $result = [];
        $totals = ['training' => 0, 'held_out' => 0, 'recommended' => 0, 'correct_when_recommended' => 0, 'abstained' => 0];
        foreach ($rows->groupBy('department_id') as $department => $group) {
            $group = $group->values();
            $train = $group->take((int) floor($group->count() * .8))->all();
            $test = $group->slice(count($train));
            $counts = ['training' => count($train), 'held_out' => $test->count(), 'recommended' => 0, 'correct_when_recommended' => 0, 'abstained' => 0];
            foreach ($test as $sample) {
                Carbon::setTestNow(Carbon::parse($sample->created_at));
                $queue = DB::table('queues')->where('queue_id', $sample->queue_id)->first();
                $recommendation = QueueIntelligence::priority($train, $queue);
                if ($recommendation['level'] === null) $counts['abstained']++;
                else {
                    $counts['recommended']++;
                    if ($recommendation['level'] === (int) $sample->priority) $counts['correct_when_recommended']++;
                }
            }
            $result[$receipt['departments'][$department]] = $counts;
            foreach ($counts as $key => $value) $totals[$key] += $value;
        }
        $totals['coverage_percent'] = round(100 * $totals['recommended'] / $totals['held_out'], 2);
        $totals['abstention_percent'] = round(100 * $totals['abstained'] / $totals['held_out'], 2);
        $totals['agreement_on_recommended_percent'] = $totals['recommended'] ? round(100 * $totals['correct_when_recommended'] / $totals['recommended'], 2) : null;
        $totals['correct_fraction_of_all_held_out_percent'] = round(100 * $totals['correct_when_recommended'] / $totals['held_out'], 2);
        $q = (object) ['queue_id' => -1, 'department_id' => 1, 'reason_for_visit' => 'Routine follow up review visit',
            'registered_at' => now()->subMinutes(10), 'queue_type' => 'qr_walk_in', 'priority' => 0];
        $probes = [];
        foreach (['majority' => [1, 1, 1, 0, 2], 'disagreement' => [0, 0, 1, 1, 2], 'insufficient' => [1, 1, 1, 1]] as $name => $levels) {
            $training = [];
            foreach ($levels as $i => $level) $training[] = (object) ['queue_id' => $i + 1, 'department_id' => 1,
                'reason_for_visit' => $q->reason_for_visit, 'wait_minutes' => 10, 'queue_type' => $q->queue_type, 'priority' => $level];
            $probes[$name] = QueueIntelligence::priority($training, $q);
        }
        $q->reason_for_visit = '';
        $probes['empty_reason'] = QueueIntelligence::priority($training, $q);
        $q->reason_for_visit = 'Unrelated vocabulary';
        $probes['unrelated_reason'] = QueueIntelligence::priority($training, $q);
        return ['retrieved_synthetic_samples' => $rows->count(), 'by_department' => $result, 'totals' => $totals,
            'controlled_probes' => $probes, 'probe_priority_unchanged' => $q->priority === 0,
            'note' => '50 examples per department, first 40 train, last 10 held out. Evaluation time equals each review timestamp; held-out labels are excluded from its training input.'];
    }

    private function integrity(array $receipt, $historical): array
    {
        $qids = $receipt['ids']['queues'];
        $checks = [];
        $checks['completed_consultations'] = $historical->count();
        $checks['active_queues'] = DB::table('queues')->whereIn('queue_id', $qids)->whereIn('queue_status', Clinic::ACTIVE)->count();
        $checks['appointments'] = DB::table('appointments')->whereIn('appointment_id', $receipt['ids']['appointments'])->count();
        $checks['bad_historical_timestamps'] = $historical->filter(fn ($r) => $r->registered_at > $r->called_at || $r->called_at > $r->started_at || $r->started_at >= $r->ended_at || $r->completed_at !== $r->ended_at)->count();
        $checks['bad_completed_status'] = $historical->where('queue_status', '!=', 'completed')->count();
        $checks['weekend_history'] = $historical->filter(fn ($r) => Carbon::parse($r->started_at)->isWeekend())->count();
        $checks['assignment_mismatches'] = DB::table('queues as q')->join('rooms as r', 'r.room_id', '=', 'q.room_id')
            ->whereIn('q.queue_id', $qids)->where(fn ($q) => $q->whereColumn('q.department_id', '!=', 'r.department_id')->orWhereColumn('q.doctor_id', '!=', 'r.doctor_id'))->count();
        $checks['missing_queue_patient'] = DB::table('queues as q')->leftJoin('users as u', 'u.user_id', '=', 'q.user_id')->whereIn('q.queue_id', $qids)->whereNull('u.user_id')->count();
        $checks['missing_priority_relationships'] = DB::table('priority_training_samples as p')->leftJoin('queues as q', 'q.queue_id', '=', 'p.queue_id')
            ->leftJoin('users as u', 'u.user_id', '=', 'p.reviewed_by')->leftJoin('roles as r', 'r.role_id', '=', 'u.role_id')
            ->whereIn('p.id', $receipt['ids']['priority_training_samples'])->where(fn ($q) => $q->whereNull('q.queue_id')->orWhereNull('u.user_id')->orWhere('r.role_name', '!=', 'staff'))->count();
        $checks['priority_field_mismatches'] = DB::table('priority_training_samples as p')->join('queues as q', 'q.queue_id', '=', 'p.queue_id')
            ->whereIn('p.id', $receipt['ids']['priority_training_samples'])->where(fn ($q) => $q->whereColumn('p.department_id', '!=', 'q.department_id')->orWhereColumn('p.priority', '!=', 'q.priority')->orWhereColumn('p.queue_type', '!=', 'q.queue_type'))->count();
        $settings = Clinic::settings();
        $checks['history_outside_operating_hours'] = $historical->filter(fn ($r) =>
            $r->registered_at < substr($r->started_at, 0, 10).' '.$settings->opening_time.':00'
            || $r->ended_at > substr($r->started_at, 0, 10).' '.$settings->closing_time.':00')->count();
        $checks['completed_appointment_mismatches'] = DB::table('appointments as a')->leftJoin('queues as q', 'q.appointment_id', '=', 'a.appointment_id')
            ->whereIn('a.appointment_id', $receipt['ids']['appointments'])->where('a.appointment_status', 'completed')
            ->where(fn ($q) => $q->whereNull('q.queue_id')->orWhere('q.queue_status', '!=', 'completed')->orWhereColumn('a.user_id', '!=', 'q.user_id')->orWhereColumn('a.department_id', '!=', 'q.department_id'))->count();
        $checks['historical_doctor_overlaps'] = 0;
        foreach ($historical->groupBy('user_id') as $group) {
            $lastEnd = null;
            foreach ($group->sortBy('started_at') as $row) {
                if ($lastEnd !== null && $row->started_at < $lastEnd) $checks['historical_doctor_overlaps']++;
                $lastEnd = max($lastEnd ?? '', $row->ended_at);
            }
        }
        $checks['synthetic_notifications'] = DB::table('notifications')->whereIn('user_id', $receipt['ids']['users'])->count();
        $checks['synthetic_push_devices'] = DB::table('push_devices')->whereIn('user_id', $receipt['ids']['users'])->count();
        $checks['synthetic_tokens'] = DB::table('personal_access_tokens')->whereIn('tokenable_id', $receipt['ids']['users'])->count();
        $checks['appointment_states'] = DB::table('appointments')->whereIn('appointment_id', $receipt['ids']['appointments'])->selectRaw('appointment_status, COUNT(*) as total')->groupBy('appointment_status')->pluck('total', 'appointment_status')->all();
        return $checks;
    }

    private function reports(array $receipt): array
    {
        $admin = User::whereHas('role', fn ($q) => $q->where('role_name', 'administrator'))->where('status', 'active')->firstOrFail();
        $start = substr(DB::table('queues')->min('registered_at'), 0, 10);
        $end = substr(DB::table('queues')->max('registered_at'), 0, 10);
        $request = Request::create('/api/reports', 'GET', ['start' => $start, 'end' => $end]);
        $request->setUserResolver(fn () => $admin);
        $report = app(ReportController::class)->index($request);
        $workspace = app(WorkspaceController::class)->index($request)->getData(true);
        $sql = DB::table('queues')->selectRaw("COUNT(*) as total, SUM(queue_status IN ('waiting','verified','assigned','called','in_consultation','skipped')) as active, SUM(queue_status = 'completed') as completed, ROUND(AVG(CASE WHEN called_at IS NOT NULL THEN GREATEST(0, TIMESTAMPDIFF(SECOND, registered_at, called_at)/60.0) END), 1) as average_wait_minutes")->first();
        $synthetic = DB::table('queues')->whereIn('queue_id', $receipt['ids']['queues'])->selectRaw("COUNT(*) as total, SUM(queue_status IN ('waiting','verified','assigned','called','in_consultation','skipped')) as active, SUM(queue_status = 'completed') as completed, ROUND(AVG(CASE WHEN called_at IS NOT NULL THEN GREATEST(0, TIMESTAMPDIFF(SECOND, registered_at, called_at)/60.0) END), 1) as average_wait_minutes")->first();
        $distribution = DB::table('queues as q')->join('departments as d', 'd.department_id', '=', 'q.department_id')->groupBy('d.department_name')->selectRaw('d.department_name, COUNT(*) as total')->pluck('total', 'department_name')->all();
        $match = true;
        foreach ((array) $sql as $key => $value) {
            $match = $match && abs((float) $value - (float) $report[$key]) < .01 && abs((float) $value - (float) $workspace['summary'][$key]) < .01;
        }
        foreach ($report['departments'] as $department) $match = $match && $department['count'] == $distribution[$department['name']];
        return ['date_range' => [$start, $end], 'report_controller' => $report, 'dashboard_summary' => $workspace['summary'],
            'independent_sql' => $sql, 'synthetic_only_sql' => $synthetic, 'department_distribution_sql' => $distribution,
            'all_metrics_match' => $match, 'ui_scope' => 'Existing controller payloads verified; Flutter visual rendering not executed here.'];
    }
}
