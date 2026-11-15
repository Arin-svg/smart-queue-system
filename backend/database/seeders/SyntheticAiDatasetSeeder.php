<?php

namespace Database\Seeders;

use App\Services\DevelopmentDatabaseBackup;
use App\Services\SyntheticAiSafety;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Random\Engine\Mt19937;
use Random\Randomizer;
use RuntimeException;

/** Versioned, additive, non-clinical fixtures. No model events or notification calls. */
class SyntheticAiDatasetSeeder extends Seeder
{
    public const PREFIX = 'SYN-AI-V1-';
    public array $result = [];
    private Randomizer $rng;

    public static function receipt(): ?array
    {
        $row = DB::table('audit_logs')->where('action', 'seed_ai_v1')->where('record_type', 'synthetic_dataset')->first();
        return $row ? json_decode($row->details, true, 512, JSON_THROW_ON_ERROR) : null;
    }

    public static function fingerprint(array $ids): string
    {
        $data = [];
        foreach (['users' => 'user_id', 'appointments' => 'appointment_id', 'queues' => 'queue_id',
            'consultations' => 'consultation_id', 'priority_training_samples' => 'id'] as $table => $key) {
            $data[$table] = DB::table($table)->whereIn($key, $ids[$table])->orderBy($key)->get()->all();
        }
        return hash('sha256', json_encode($data, JSON_THROW_ON_ERROR));
    }

    public function run(): void
    {
        DevelopmentDatabaseBackup::assertLocal();
        SyntheticAiSafety::pause();
        if ($receipt = self::receipt()) {
            if (! hash_equals($receipt['fingerprint'], self::fingerprint($receipt['ids']))) {
                throw new RuntimeException('Dataset already exists but has been edited. Refusing to overwrite or duplicate it.');
            }
            $this->result = ['inserted' => 0, 'already_present' => true, 'receipt' => $receipt];
            return;
        }
        if (DB::table('users')->where('user_identifier', 'like', self::PREFIX.'%')->exists()
            || DB::table('queues')->where('queue_number', 'like', 'SAI1-%')->exists()) {
            throw new RuntimeException('Synthetic namespace collision without a receipt; inspect before continuing.');
        }
        $anchor = Carbon::parse(config('sqs_ai.as_of') ?: now()->toDateTimeString());
        if ($anchor->gt(now())) {
            throw new RuntimeException('The evaluation anchor must not be in the future.');
        }
        $seed = (int) config('sqs_ai.seed', 20261115);
        $this->rng = new Randomizer(new Mt19937($seed));
        $backup = app(DevelopmentDatabaseBackup::class);
        $manifestPath = $backup->create(config('sqs_ai.mysqldump', 'C:/xampp/mysql/bin/mysqldump.exe'));
        $manifest = $backup->verify($manifestPath);
        $this->command?->info('Fresh verified backup: '.$manifestPath);

        $this->result = DB::transaction(function () use ($anchor, $seed, $backup, $manifest, $manifestPath) {
            $settings = DB::table('clinic_settings')->where('id', 1)->lockForUpdate()->first();
            if (self::receipt()) {
                throw new RuntimeException('Another seed run completed; rerun to verify its receipt.');
            }
            $names = ['Dental Clinic', 'General Consultation', 'Health Screening'];
            $departments = DB::table('departments')->whereIn('department_name', $names)->where('status', 'active')->orderBy('department_id')->get();
            if ($departments->count() !== 3) {
                throw new RuntimeException('Expected three active consultation departments. Configure explicit selection before seeding a different clinic.');
            }
            $staff = DB::table('users as u')->join('roles as r', 'r.role_id', '=', 'u.role_id')
                ->where('r.role_name', 'staff')->where('u.status', 'active')->orderBy('u.user_id')->pluck('u.user_id')->all();
            if (! $staff) {
                throw new RuntimeException('An existing active staff reviewer reference is required.');
            }
            $rooms = [];
            foreach ($departments as $department) {
                $rooms[$department->department_id] = DB::table('rooms as room')->join('users as u', 'u.user_id', '=', 'room.doctor_id')
                    ->join('roles as r', 'r.role_id', '=', 'u.role_id')->where('r.role_name', 'doctor')->where('u.status', 'active')
                    ->where('room.status', 'available')->where('room.department_id', $department->department_id)->orderBy('room.room_id')->get(['room.*'])->all();
                if (! $rooms[$department->department_id]) {
                    throw new RuntimeException('No available room/active doctor for department '.$department->department_id);
                }
            }
            $ids = array_fill_keys(['users', 'appointments', 'queues', 'consultations', 'priority_training_samples'], []);
            $patientRole = DB::table('roles')->where('role_name', 'patient')->value('role_id');
            // No usable password is exposed and all addresses are reserved, non-deliverable .invalid names.
            $password = Hash::make(bin2hex(random_bytes(32)));
            for ($i = 1; $i <= 332; $i++) {
                $ids['users'][] = DB::table('users')->insertGetId(['role_id' => $patientRole,
                    'user_identifier' => self::PREFIX.str_pad((string) $i, 4, '0', STR_PAD_LEFT),
                    'name' => 'SYNTHETIC AI Patient '.str_pad((string) $i, 4, '0', STR_PAD_LEFT),
                    'email' => 'sqs-ai-v1-'.$i.'@example.invalid', 'password' => $password,
                    'status' => 'active', 'created_at' => $anchor->copy()->subDays(120), 'updated_at' => $anchor], 'user_id');
            }
            $doctorSlots = [];
            $historicStart = $anchor->copy()->subDays(110)->startOfDay();
            while ($historicStart->isWeekend()) $historicStart->addDay();
            $opening = Carbon::parse($historicStart->toDateString().' '.$settings->opening_time);
            $closing = Carbon::parse($historicStart->toDateString().' '.$settings->closing_time);
            $dayMinutes = (int) $opening->diffInMinutes($closing, false);
            $slotStep = (int) (ceil(90 / $settings->slot_minutes) * $settings->slot_minutes);
            $firstOffset = $slotStep;
            $slotsPerDay = (int) floor(($dayMinutes - 65 - $firstOffset) / $slotStep) + 1;
            if ($slotsPerDay < 1) throw new RuntimeException('Operating day too short for these historical fixtures.');
            $contexts = [];
            for ($i = 0; $i < 300; $i++) {
                $dept = $departments[$i % 3];
                $ordinal = intdiv($i, 3);
                $room = $rooms[$dept->department_id][$ordinal % count($rooms[$dept->department_id])];
                $isAppointment = in_array($ordinal, [4, 19, 34, 49, 64, 79], true);
                $type = $isAppointment ? 'appointment' : 'qr_walk_in';
                $baseline = ['Dental Clinic' => 25, 'General Consultation' => 17, 'Health Screening' => 20][$dept->department_name];
                // Broad skewed noise and occasional longer encounters dominate modest covariate effects.
                $u1 = max(0.000001, $this->rng->getInt(1, 999999) / 1000000);
                $u2 = $this->rng->getInt(1, 999999) / 1000000;
                $noise = sqrt(-2 * log($u1)) * cos(2 * M_PI * $u2);
                $minutes = (int) max(4, min(65, round($baseline * exp(0.43 * $noise)
                    + ($isAppointment ? -2 : 0) + $this->rng->getInt(-3, 3) + ($this->rng->getInt(1, 12) === 1 ? 12 : 0))));
                // One globally serialized schedule per doctor, including doctors shared by departments.
                do {
                    $position = $doctorSlots[$room->doctor_id] ?? 0;
                    $doctorSlots[$room->doctor_id] = $position + 1;
                    $day = $historicStart->copy()->addWeekdays(intdiv($position, $slotsPerDay));
                    $start = Carbon::parse($day->toDateString().' '.$settings->opening_time)->addMinutes($firstOffset + ($position % $slotsPerDay) * $slotStep);
                    $end = $start->copy()->addMinutes($minutes)->addSeconds($this->rng->getInt(0, 59));
                    $conflict = DB::table('consultations')->where('user_id', $room->doctor_id)->where('started_at', '<', $end)->where('ended_at', '>', $start)->exists()
                        || DB::table('appointments')->where('doctor_id', $room->doctor_id)->whereDate('appointment_date', $day)->where('appointment_time', $start->format('H:i:s'))->exists();
                } while ($conflict);
                if ($end->gte($anchor->copy()->startOfDay())) throw new RuntimeException('Historical allocation extends into present; increase history window.');
                $wait = $this->rng->getInt(6, 65) + ($this->rng->getInt(1, 10) === 1 ? 10 : 0);
                $called = $start->copy()->subSeconds($this->rng->getInt(20, 150));
                $registered = $called->copy()->subMinutes($wait);
                $reviewWait = $this->rng->getInt(2, min(20, $wait - 1));
                $review = $registered->copy()->addMinutes($reviewWait);
                $family = $this->rng->getInt(0, 9);
                $reason = $family < 4 ? 'Routine follow up review '.($ordinal % 2 ? 'scheduled' : 'visit')
                    : ($family < 8 ? 'New concern assessment '.($ordinal % 2 ? 'visit' : 'requested') : 'Specific request '.$this->rng->getInt(1000, 9999));
                $roll = $this->rng->getInt(1, 100);
                $priority = $family < 4 ? ($roll <= 65 ? 0 : ($roll <= 88 ? 1 : 2)) : ($roll <= 30 ? 0 : ($roll <= 75 ? 1 : 2));
                $reviewed = $ordinal % 2 === 0;
                $reviewer = $staff[$ordinal % count($staff)];
                $appointmentId = null;
                if ($isAppointment) {
                    $appointmentId = DB::table('appointments')->insertGetId(['user_id' => $ids['users'][$i], 'department_id' => $dept->department_id,
                        'doctor_id' => $room->doctor_id, 'appointment_date' => $start->toDateString(), 'appointment_time' => $start->format('H:i:s'),
                        'appointment_status' => 'completed', 'reason_for_visit' => $reason,
                        'created_at' => $registered->copy()->subDays(5), 'updated_at' => $end], 'appointment_id');
                    $ids['appointments'][] = $appointmentId;
                }
                $queueId = DB::table('queues')->insertGetId(['user_id' => $ids['users'][$i], 'department_id' => $dept->department_id,
                    'room_id' => $room->room_id, 'doctor_id' => $room->doctor_id, 'appointment_id' => $appointmentId,
                    'verified_by' => $reviewer, 'verified_at' => $registered->copy()->addMinute(),
                    'queue_number' => 'SAI1-H'.str_pad((string) ($i + 1), 4, '0', STR_PAD_LEFT),
                    'queue_type' => $type, 'queue_status' => 'completed', 'reason_for_visit' => $reason,
                    'registered_at' => $registered, 'called_at' => $called, 'completed_at' => $end,
                    'priority' => $reviewed ? $priority : 0,
                    'priority_note' => $reviewed ? 'SYNTHETIC staff-review simulation; not clinically validated.' : null,
                    'created_at' => $registered, 'updated_at' => $end], 'queue_id');
                $ids['queues'][] = $queueId;
                $ids['consultations'][] = DB::table('consultations')->insertGetId(['queue_id' => $queueId, 'user_id' => $room->doctor_id,
                    'room_id' => $room->room_id, 'consultation_status' => 'completed', 'started_at' => $start, 'ended_at' => $end,
                    'created_at' => $called, 'updated_at' => $end], 'consultation_id');
                if ($reviewed) {
                    $ids['priority_training_samples'][] = DB::table('priority_training_samples')->insertGetId(['queue_id' => $queueId,
                        'department_id' => $dept->department_id, 'reason_for_visit' => $reason, 'queue_type' => $type,
                        'wait_minutes' => $reviewWait, 'priority' => $priority, 'reviewed_by' => $reviewer, 'created_at' => $review]);
                }
                $contexts[$dept->department_id] = $room;
            }
            $occupied = DB::table('queues')->whereIn('queue_status', ['called', 'in_consultation'])->pluck('doctor_id')->all();
            $liveStates = array_merge(array_fill(0, 5, 'waiting'), array_fill(0, 5, 'verified'), array_fill(0, 8, 'assigned'), ['called', 'in_consultation']);
            foreach ($liveStates as $i => $status) {
                $dept = $departments[$i % 3];
                $room = $contexts[$dept->department_id];
                if (in_array($status, ['called', 'in_consultation'])) {
                    $room = collect($contexts)->first(fn ($r) => ! in_array($r->doctor_id, $occupied));
                    if (! $room) throw new RuntimeException('Two free distinct doctors are required for active called/in-consultation fixtures.');
                    $dept = $departments->firstWhere('department_id', $room->department_id);
                    $occupied[] = $room->doctor_id;
                }
                $registered = $anchor->copy()->subMinutes(100 - $i * 3);
                $assigned = ! in_array($status, ['waiting', 'verified']);
                $called = in_array($status, ['called', 'in_consultation']) ? $anchor->copy()->subMinutes(8) : null;
                $id = DB::table('queues')->insertGetId(['user_id' => $ids['users'][300 + $i], 'department_id' => $dept->department_id,
                    'doctor_id' => $assigned ? $room->doctor_id : null, 'room_id' => $assigned ? $room->room_id : null,
                    'verified_by' => $status !== 'waiting' ? $staff[0] : null, 'verified_at' => $status !== 'waiting' ? $registered->copy()->addMinute() : null,
                    'queue_number' => 'SAI1-A'.str_pad((string) ($i + 1), 3, '0', STR_PAD_LEFT), 'queue_type' => 'qr_walk_in',
                    'queue_status' => $status, 'reason_for_visit' => $i % 4 === 0 ? 'Unfamiliar one off request '.$i : 'Routine follow up review visit',
                    'registered_at' => $registered, 'called_at' => $called, 'priority' => 0, 'created_at' => $registered, 'updated_at' => $anchor], 'queue_id');
                $ids['queues'][] = $id;
                if ($called) {
                    $ids['consultations'][] = DB::table('consultations')->insertGetId(['queue_id' => $id, 'user_id' => $room->doctor_id,
                        'room_id' => $room->room_id, 'consultation_status' => $status,
                        'started_at' => $status === 'in_consultation' ? $anchor->copy()->subMinutes(5) : null,
                        'created_at' => $called, 'updated_at' => $anchor], 'consultation_id');
                }
            }
            // 18 historical appointments above + 12 future workflow examples = exactly 30.
            $future = $anchor->copy()->addDay()->startOfDay();
            while ($future->isWeekend()) $future->addDay();
            for ($i = 0; $i < 12; $i++) {
                $dept = $departments[$i % 3];
                $room = $contexts[$dept->department_id];
                $at = Carbon::parse($future->copy()->addWeekdays($i)->toDateString().' '.$settings->opening_time)->addMinutes($settings->slot_minutes * 2);
                if (DB::table('appointments')->where('doctor_id', $room->doctor_id)->whereDate('appointment_date', $at)->where('appointment_time', $at->format('H:i:s'))->whereIn('appointment_status', ['pending', 'confirmed'])->exists()
                    || DB::table('appointments')->where('department_id', $dept->department_id)->whereDate('appointment_date', $at)->where('appointment_time', $at->format('H:i:s'))->whereIn('appointment_status', ['pending', 'confirmed'])->count() >= $settings->slot_capacity
                    || $at->copy()->addMinutes($settings->slot_minutes)->gt(Carbon::parse($at->toDateString().' '.$settings->closing_time))) {
                    throw new RuntimeException('Future fixture appointment conflicts with an existing booking.');
                }
                $ids['appointments'][] = DB::table('appointments')->insertGetId(['user_id' => $ids['users'][320 + $i],
                    'department_id' => $dept->department_id, 'doctor_id' => $room->doctor_id, 'appointment_date' => $at->toDateString(),
                    'appointment_time' => $at->format('H:i:s'), 'appointment_status' => $i % 2 ? 'confirmed' : 'pending',
                    'reason_for_visit' => 'SYNTHETIC appointment workflow exercise', 'created_at' => $anchor, 'updated_at' => $anchor], 'appointment_id');
            }
            $changed = $backup->preserved($manifest['tables']);
            // External login activity may update token last_used_at; domain/config records must remain identical.
            $changed = array_values(array_filter($changed, fn ($v) => $v['table'] !== 'personal_access_tokens'));
            if ($changed) throw new RuntimeException('Pre-existing records changed since backup: '.json_encode($changed));
            $receipt = ['version' => 1, 'seed' => $seed, 'as_of' => $anchor->toDateTimeString(), 'ids' => $ids,
                'departments' => $departments->pluck('department_name', 'department_id')->all(), 'backup_manifest' => $manifestPath,
                'source_hashes' => ['QueueIntelligence' => hash_file('sha256', app_path('Services/QueueIntelligence.php')), 'Clinic' => hash_file('sha256', app_path('Services/Clinic.php'))],
                'fingerprint' => self::fingerprint($ids), 'counts' => array_map('count', $ids)];
            DB::table('audit_logs')->insert(['actor_id' => null, 'action' => 'seed_ai_v1', 'record_type' => 'synthetic_dataset',
                'record_id' => null, 'details' => json_encode($receipt, JSON_THROW_ON_ERROR), 'created_at' => now()]);
            return ['inserted' => $receipt['counts'], 'already_present' => false, 'receipt' => $receipt];
        });
    }
}
