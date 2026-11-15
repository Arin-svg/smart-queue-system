<?php

namespace Tests\Unit;

use App\Services\QueueIntelligence;
use App\Services\SyntheticAiEvaluation;
use App\Services\SyntheticAiSafety;
use Carbon\Carbon;
use Tests\TestCase;

class SyntheticAiEvaluationTest extends TestCase
{
    private function samples(int $count): array
    {
        $samples = [];
        for ($i = 0; $i < $count; $i++) {
            $samples[] = ['minutes' => 8 + (($i * 17) % 29), 'hour' => 8 + ($i % 8), 'doctor_id' => $i % 2,
                'queue_type' => $i % 3 ? 'qr_walk_in' : 'appointment', 'ended_at' => Carbon::parse('2026-08-01')->addHours($i)->toDateTimeString()];
        }
        return $samples;
    }

    public function test_nineteen_samples_use_configured_average_and_twenty_enable_comparison(): void
    {
        $small = SyntheticAiEvaluation::durationMetrics($this->samples(19), 15);
        $this->assertEquals(15, $small['prediction']);
        $this->assertNull($small['selected_mae']);
        $enough = SyntheticAiEvaluation::durationMetrics($this->samples(20), 15);
        $this->assertSame(16, $enough['train']);
        $this->assertSame(4, $enough['validation']);
        $this->assertSame([3, 5, 7], array_keys($enough['knn_mae_by_k']));
        $this->assertLessThan($enough['validation_start'], $enough['training_end']);
    }

    public function test_diagnostics_match_production_and_do_not_change_samples(): void
    {
        $samples = $this->samples(100);
        $before = $samples;
        $metrics = SyntheticAiEvaluation::durationMetrics($samples, 15);
        [, $method, $mae] = QueueIntelligence::duration($samples, (object) [], 15);
        $this->assertSame($method, $metrics['method']);
        $this->assertEquals($mae, $metrics['selected_mae']);
        $this->assertSame(80, $metrics['train']);
        $this->assertSame(20, $metrics['validation']);
        $this->assertSame($before, $samples);
    }

    public function test_disagreement_abstains_without_mutating_approved_priority(): void
    {
        $queue = (object) ['queue_id' => 99, 'department_id' => 1, 'registered_at' => now()->subMinutes(10),
            'reason_for_visit' => 'Routine follow up review visit', 'queue_type' => 'qr_walk_in', 'priority' => 2];
        $samples = [];
        foreach ([0, 0, 1, 1, 2] as $id => $priority) {
            $samples[] = (object) ['queue_id' => $id, 'department_id' => 1, 'wait_minutes' => 10,
                'reason_for_visit' => $queue->reason_for_visit, 'queue_type' => $queue->queue_type, 'priority' => $priority];
        }
        $result = QueueIntelligence::priority($samples, $queue);
        $this->assertNull($result['level']);
        $this->assertStringContainsString('disagree', $result['reason']);
        $this->assertSame(2, $queue->priority);
        $queue->reason_for_visit = '';
        $this->assertNull(QueueIntelligence::priority($samples, $queue)['level']);
    }

    public function test_local_safety_marker_does_not_affect_testing_environment(): void
    {
        $this->assertFalse(SyntheticAiSafety::paused());
    }
}
