<?php

namespace App\Services;

use Carbon\Carbon;

/** Historical, advisory models. Never autonomously changes clinical priority. */
class QueueIntelligence
{
    private const MIN_TRAINING_SAMPLES = 20;

    /** Returns [predicted consultation minutes, method, holdout MAE in minutes|null]. */
    public static function duration(array $samples, object $queue, float $fallback): array
    {
        $fallback = max(1.0, $fallback);
        $samples = array_values(array_filter($samples, static fn ($s) =>
            isset($s['minutes'], $s['hour'], $s['queue_type']) &&
            is_numeric($s['minutes']) && (float) $s['minutes'] > 0 &&
            (float) $s['minutes'] < 240
        ));

        // Clinic::estimates supplies samples oldest-first. Preserve that order:
        // the last 20% is held out to test performance on later consultations.
        if (count($samples) < self::MIN_TRAINING_SAMPLES) {
            return [$fallback, 'Configured average (requires 20 completed consultations)', null];
        }

        $split = (int) floor(count($samples) * 0.8);
        $train = array_slice($samples, 0, $split);
        $validation = array_slice($samples, $split);
        $baseline = self::meanMinutes($train);

        $baselineError = 0.0;
        foreach ($validation as $sample) {
            $baselineError += abs($baseline - (float) $sample['minutes']);
        }
        $baselineMae = $baselineError / count($validation);

        $bestK = null;
        $bestMae = INF;
        foreach ([3, 5, 7] as $k) {
            if (count($train) < $k) {
                continue;
            }
            $error = 0.0;
            foreach ($validation as $sample) {
                $error += abs(self::regress($train, $sample, $k) - (float) $sample['minutes']);
            }
            $mae = $error / count($validation);
            if ($mae < $bestMae) {
                $bestMae = $mae;
                $bestK = $k;
            }
        }

        // MAE always describes the SELECTED method, not a rejected model.
        if ($bestK === null || $bestMae >= $baselineMae) {
            return [round($baseline, 2), 'Historical average (KNN did not beat validation baseline)', round($baselineMae, 2)];
        }

        $target = [
            'hour' => (int) now()->format('G'),
            'doctor_id' => $queue->doctor_id ?? null,
            'queue_type' => $queue->queue_type ?? '',
        ];

        return [
            round(self::regress($samples, $target, $bestK), 2),
            'KNN regression (k='.$bestK.'; chronological validation)',
            round($bestMae, 2),
        ];
    }

    private static function meanMinutes(array $samples): float
    {
        return array_sum(array_map(static fn ($s) => (float) $s['minutes'], $samples)) / count($samples);
    }

    private static function regress(array $samples, array $target, int $k): float
    {
        usort($samples, static fn ($a, $b) => self::distance($a, $target) <=> self::distance($b, $target));
        $nearest = array_slice($samples, 0, min($k, count($samples)));
        return max(1.0, self::meanMinutes($nearest));
    }

    private static function distance(array $a, array $b): float
    {
        // Hour is circular: 23:00 and 00:00 are one hour apart.
        $hourGap = abs((int) $a['hour'] - (int) $b['hour']);
        $hourDistance = min($hourGap, 24 - $hourGap) / 12;
        $doctorPenalty = ($a['doctor_id'] ?? null) == ($b['doctor_id'] ?? null) ? 0.0 : 0.5;
        $typePenalty = ($a['queue_type'] ?? '') === ($b['queue_type'] ?? '') ? 0.0 : 0.5;
        return $hourDistance + $doctorPenalty + $typePenalty;
    }

    /** Advisory only: the clinic must clinically review all urgency decisions. */
    public static function priority(array $samples, object $queue): array
    {
        $candidates = [];
        $wait = max(0, Carbon::parse($queue->registered_at)->diffInMinutes(now(), false));
        $words = self::words((string) ($queue->reason_for_visit ?? ''));
        if (!$words) {
            return ['level' => null, 'reason' => 'No reason for visit supplied. Staff review required.', 'samples' => 0];
        }

        foreach ($samples as $s) {
            if ($s->queue_id == $queue->queue_id || $s->department_id != $queue->department_id) {
                continue;
            }
            $other = self::words((string) ($s->reason_for_visit ?? ''));
            $union = count(array_unique(array_merge($words, $other)));
            $similarity = $union ? count(array_intersect($words, $other)) / $union : 0;
            if ($similarity < 0.5) {
                continue;
            }
            $candidates[] = [
                'priority' => (int) $s->priority,
                'distance' => 1 - $similarity
                    + min(1, abs((float) $s->wait_minutes - $wait) / 120)
                    + ($s->queue_type === $queue->queue_type ? 0 : 0.25),
            ];
        }
        if (count($candidates) < 5) {
            return ['level' => null, 'reason' => 'Insufficient comparable staff-reviewed cases. Manual review required.', 'samples' => count($candidates)];
        }
        usort($candidates, static fn ($a, $b) => $a['distance'] <=> $b['distance']);
        $votes = array_count_values(array_column(array_slice($candidates, 0, 5), 'priority'));
        arsort($votes);
        $level = (int) array_key_first($votes);
        if ($votes[$level] < 3) {
            return ['level' => null, 'reason' => 'Historical staff decisions disagree. Manual review required.', 'samples' => count($candidates)];
        }
        return [
            'level' => $level,
            'reason' => 'Historical similarity recommendation only; staff clinical review and approval required.',
            'agreement' => $votes[$level] / 5,
            'samples' => count($candidates),
        ];
    }

    private static function words(string $text): array
    {
        return array_values(array_unique(preg_split('/[^\pL\pN]+/u', mb_strtolower($text), -1, PREG_SPLIT_NO_EMPTY) ?: []));
    }
}
