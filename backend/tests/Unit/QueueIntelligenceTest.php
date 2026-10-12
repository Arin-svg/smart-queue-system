<?php

namespace Tests\Unit;

use App\Services\QueueIntelligence;
use Tests\TestCase;

class QueueIntelligenceTest extends TestCase
{
    public function test_wait_model_abstains_with_insufficient_history(): void
    {
        [$duration, $method, $error] = QueueIntelligence::duration([], (object) [], 15);
        $this->assertEquals(15, $duration);
        $this->assertStringStartsWith('Configured average', $method);
        $this->assertNull($error);
    }

    public function test_duration_model_learns_from_history_and_reports_holdout_error(): void
    {
        $samples = [];
        for ($i = 0; $i < 20; $i++) {
            $samples[] = ['minutes' => 12, 'hour' => 9, 'doctor_id' => 3, 'queue_type' => 'qr_walk_in'];
        }
        [$duration, $method, $error] = QueueIntelligence::duration($samples, (object) ['doctor_id' => 3, 'queue_type' => 'qr_walk_in'], 15);
        $this->assertEquals(12, $duration);
        $this->assertStringStartsWith('AI:', $method);
        $this->assertEquals(0, $error);
    }

    public function test_priority_requires_similar_human_labels_and_never_changes_queue(): void
    {
        $queue = (object) ['queue_id' => 20, 'department_id' => 1, 'reason_for_visit' => 'Follow-up Visit',
            'registered_at' => now()->subMinutes(20), 'queue_type' => 'qr_walk_in', 'priority' => 0];
        $this->assertNull(QueueIntelligence::priority([], $queue)['level']);
        $samples = [];
        for ($i = 1; $i <= 5; $i++) {
            $samples[] = (object) ['queue_id' => $i, 'department_id' => 1,
                'reason_for_visit' => 'Follow-up Visit', 'queue_type' => 'qr_walk_in', 'wait_minutes' => 20, 'priority' => 1];
        }
        $result = QueueIntelligence::priority($samples, $queue);
        $this->assertEquals(1, $result['level']);
        $this->assertEquals(0, $queue->priority);
        $queue->reason_for_visit = 'Unrelated request';
        $this->assertNull(QueueIntelligence::priority($samples, $queue)['level']);
    }
}
