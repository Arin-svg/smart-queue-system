<?php

namespace App\Console\Commands;

use App\Services\SyntheticAiEvaluation;
use Illuminate\Console\Command;

class EvaluateAiDataset extends Command
{
    protected $signature = 'sqs:ai-evaluate {--output= : Optional JSON destination}';
    protected $description = 'Evaluate frozen synthetic data using original services and compare report/dashboard totals with SQL';

    public function handle(SyntheticAiEvaluation $evaluation): int
    {
        $result = $evaluation->run();
        $output = $this->option('output') ?: base_path('../.tmp/sqs-ai/evaluation.json');
        if (! is_dir(dirname($output))) mkdir(dirname($output), 0700, true);
        file_put_contents($output, json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
        $this->table(['Department', 'N', 'Train', 'Validation', 'K3 MAE', 'K5 MAE', 'K7 MAE', 'Baseline', 'Selected K'],
            collect($result['duration'])->map(fn ($m, $name) => [$name, $m['samples'], $m['train'], $m['validation'],
                $m['knn_mae_by_k'][3], $m['knn_mae_by_k'][5], $m['knn_mae_by_k'][7], $m['baseline_mae'], $m['selected_k'] ?? 'Average'])->values()->all());
        $this->line('Priority: '.json_encode($result['priority']['totals']));
        $this->line('Integrity: '.json_encode($result['integrity']));
        $this->line('Reports match SQL: '.($result['reports']['all_metrics_match'] ? 'YES' : 'NO'));
        $this->line('Queue order unchanged: '.($result['queue_order_unchanged'] ? 'YES' : 'NO'));
        $this->info('Full results: '.$output);
        $valid = $result['reports']['all_metrics_match'] && $result['queue_order_unchanged']
            && $result['synthetic_fingerprint_unchanged'] && $result['production_algorithms_unchanged'];
        foreach (['bad_historical_timestamps', 'bad_completed_status', 'weekend_history', 'assignment_mismatches',
            'missing_queue_patient', 'missing_priority_relationships', 'priority_field_mismatches',
            'history_outside_operating_hours', 'completed_appointment_mismatches', 'historical_doctor_overlaps',
            'synthetic_notifications', 'synthetic_push_devices', 'synthetic_tokens'] as $check) {
            $valid = $valid && $result['integrity'][$check] === 0;
        }
        return $valid ? self::SUCCESS : self::FAILURE;
    }
}
