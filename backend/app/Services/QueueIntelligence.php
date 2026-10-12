<?php

namespace App\Services;

use Carbon\Carbon;

/** Local, data-driven nearest-neighbour models; never changes queue priority. */
class QueueIntelligence
{
    public static function duration(array $samples, object $queue, float $fallback): array
    {
        if (count($samples) < 10) {
            return [$fallback, 'Configured average (learning needs 10 completed consultations)', null];
        }
        // Reserve the latest 20% for a chronological holdout. Use the learned model
        // only when its measured error is no worse than the training-set average.
        $split = max(5, (int) floor(count($samples) * .8));
        $train = array_slice($samples, 0, $split);
        $validation = array_slice($samples, $split);
        $average = array_sum(array_column($train, 'minutes')) / count($train);
        $error = $baseline = 0;
        foreach ($validation as $sample) {
            $error += abs(self::regress($train, $sample) - $sample['minutes']);
            $baseline += abs($average - $sample['minutes']);
        }
        $mae = count($validation) ? $error / count($validation) : null;
        if ($error > $baseline) {
            return [$average, 'Recent consultation average (model did not improve validation error)', $mae];
        }
        $features = ['hour' => (int) now()->format('G'), 'doctor_id' => $queue->doctor_id,
            'queue_type' => $queue->queue_type];

        return [self::regress($samples, $features), 'AI: nearest-neighbour regression on completed consultations', $mae];
    }

    private static function regress(array $samples, array $target): float
    {
        usort($samples, fn ($a, $b) => self::distance($a, $target) <=> self::distance($b, $target));
        $nearest = array_slice($samples, 0, 5);

        return max(1, array_sum(array_column($nearest, 'minutes')) / count($nearest));
    }

    private static function distance(array $a, array $b): float
    {
        return abs($a['hour'] - $b['hour']) / 12
            + ($a['doctor_id'] == $b['doctor_id'] ? 0 : .5)
            + ($a['queue_type'] === $b['queue_type'] ? 0 : .5);
    }

    public static function priority(array $samples, object $queue): array
    {
        $candidates = [];
        $wait = max(0, Carbon::parse($queue->registered_at)->diffInMinutes(now(), false));
        $words = self::words($queue->reason_for_visit);
        foreach ($samples as $s) {
            if ($s->queue_id == $queue->queue_id || $s->department_id != $queue->department_id) {
                continue;
            }
            $other = self::words($s->reason_for_visit);
            $union = count(array_unique(array_merge($words, $other)));
            $similarity = $union ? count(array_intersect($words, $other)) / $union : 0;
            if ($similarity < .5) {
                continue;
            }
            $candidates[] = ['priority' => $s->priority,
                'distance' => 1 - $similarity + min(1, abs($s->wait_minutes - $wait) / 120)
                    + ($s->queue_type === $queue->queue_type ? 0 : .25)];
        }
        if (count($candidates) < 5) {
            return ['level' => null, 'reason' => 'More comparable staff-reviewed cases are needed. Review manually.', 'samples' => count($candidates)];
        }
        usort($candidates, fn ($a, $b) => $a['distance'] <=> $b['distance']);
        $votes = array_count_values(array_column(array_slice($candidates, 0, 5), 'priority'));
        arsort($votes);
        $level = (int) array_key_first($votes);
        if ($votes[$level] < 3) {
            return ['level' => null, 'reason' => 'Previous staff decisions differ. Review manually.', 'samples' => count($candidates)];
        }

        return ['level' => $level, 'reason' => 'AI recommendation from 5 similar staff-reviewed visits. Staff approval required.',
            'agreement' => $votes[$level] / 5, 'samples' => count($candidates)];
    }

    private static function words(string $text): array
    {
        return array_values(array_unique(preg_split('/[^\pL\pN]+/u', mb_strtolower($text), -1, PREG_SPLIT_NO_EMPTY)));
    }
}
