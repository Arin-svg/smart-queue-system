<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\ClinicNotifications;
use Carbon\Carbon;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ClinicWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-10-05 08:00:00'));
        DB::unprepared(<<<'SQL'
CREATE TABLE roles (role_id INTEGER PRIMARY KEY, role_name TEXT UNIQUE);
CREATE TABLE users (user_id INTEGER PRIMARY KEY AUTOINCREMENT, role_id INTEGER, user_identifier TEXT UNIQUE, name TEXT, email TEXT UNIQUE, phone_no TEXT, password TEXT, status TEXT DEFAULT 'active', remember_token TEXT, created_at DATETIME, updated_at DATETIME);
CREATE TABLE departments (department_id INTEGER PRIMARY KEY, department_name TEXT, department_code TEXT UNIQUE, description TEXT, status TEXT DEFAULT 'active', created_at DATETIME, updated_at DATETIME);
CREATE TABLE rooms (room_id INTEGER PRIMARY KEY, department_id INTEGER, doctor_id INTEGER, room_name TEXT, room_number TEXT, status TEXT DEFAULT 'available', created_at DATETIME, updated_at DATETIME);
CREATE TABLE appointments (appointment_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, department_id INTEGER, doctor_id INTEGER, appointment_date TEXT, appointment_time TEXT, appointment_status TEXT, reason_for_visit TEXT, created_at DATETIME, updated_at DATETIME);
CREATE TABLE queues (queue_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, department_id INTEGER, doctor_id INTEGER, room_id INTEGER, appointment_id INTEGER UNIQUE, verified_by INTEGER, verified_at DATETIME, queue_number TEXT UNIQUE, queue_type TEXT, queue_status TEXT, reason_for_visit TEXT, registered_at DATETIME, called_at DATETIME, completed_at DATETIME, estimated_waiting_time INTEGER, priority INTEGER DEFAULT 0, priority_note TEXT, created_at DATETIME, updated_at DATETIME);
CREATE TABLE consultations (consultation_id INTEGER PRIMARY KEY AUTOINCREMENT, queue_id INTEGER UNIQUE, user_id INTEGER, room_id INTEGER, consultation_status TEXT, started_at DATETIME, ended_at DATETIME, created_at DATETIME, updated_at DATETIME);
CREATE TABLE notifications (notification_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, queue_id INTEGER, notification_title TEXT, notification_message TEXT, notification_status TEXT, sent_at DATETIME, read_at DATETIME, created_at DATETIME, updated_at DATETIME);
SQL);
        foreach (['patient', 'staff', 'doctor', 'administrator'] as $i => $role) {
            DB::table('roles')->insert(['role_id' => $i + 1, 'role_name' => $role]);
            User::create(['role_id' => $i + 1, 'user_identifier' => strtoupper($role).'001', 'name' => ucfirst($role),
                'email' => $role.'@example.test', 'password' => 'TestPassword123!', 'status' => 'active']);
        }
        User::create(['role_id' => 1, 'user_identifier' => 'PATIENT002', 'name' => 'Second Patient', 'email' => 'second@example.test', 'password' => 'TestPassword123!', 'status' => 'active']);
        DB::table('departments')->insert([['department_id' => 1, 'department_name' => 'General Consultation', 'department_code' => 'GC'], ['department_id' => 2, 'department_name' => 'Dental Clinic', 'department_code' => 'DEN']]);
        DB::table('rooms')->insert(['room_id' => 1, 'department_id' => 1, 'doctor_id' => 3, 'room_name' => 'Consultation Room 1', 'room_number' => 'R101']);
    }

    public function test_push_delivers_only_owned_alerts_once_and_removes_revoked_sessions(): void
    {
        $token = User::findOrFail(1)->createToken('test')->accessToken;
        DB::table('push_devices')->insert([
            'user_id' => 1, 'access_token_id' => $token->id,
            'token_hash' => hash('sha256', 'device'), 'token' => Crypt::encryptString('device'),
            'last_notification_id' => 0, 'created_at' => now(), 'updated_at' => now(),
        ]);
        \App\Services\Clinic::notify(1, 'Your turn', 'Go to room 1', 12);
        \App\Services\Clinic::notify(5, 'Private', 'Another patient');
        \Illuminate\Support\Facades\Cache::put('firebase.push.access', 'test-access', 60);
        \Illuminate\Support\Facades\Http::preventStrayRequests();
        \Illuminate\Support\Facades\Http::fake(['fcm.googleapis.com/*' => \Illuminate\Support\Facades\Http::response(['name' => 'sent'])]);
        $service = new class extends \App\Services\FirebasePush {
            protected function credentials(): array { return ['project_id' => 'test']; }
        };
        $this->assertSame(1, $service->deliver());
        $this->assertSame(0, $service->deliver());
        \Illuminate\Support\Facades\Http::assertSent(fn ($r) => $r['message']['token'] === 'device' && $r['message']['data']['destination'] === 'My Queue' && $r['message']['data']['body'] === 'Go to room 1');
        \Illuminate\Support\Facades\Http::assertSentCount(1);
        $token->delete();
        $service->deliver();
        $this->assertDatabaseCount('push_devices', 0);
    }

    public function test_bulk_read_only_updates_the_signed_in_users_alerts(): void
    {
        \App\Services\Clinic::notify(1, 'Own alert', 'Message');
        \App\Services\Clinic::notify(5, 'Other alert', 'Message');
        $ids = DB::table('notifications')->pluck('notification_id')->all();
        $this->asUser(1)->postJson('/api/notifications/read', ['ids' => $ids])->assertOk();
        $this->assertDatabaseHas('notifications', ['user_id' => 1, 'notification_status' => 'read']);
        $this->assertDatabaseHas('notifications', ['user_id' => 5, 'notification_status' => 'sent']);
    }

    public function test_verification_alerts_are_sent_only_to_active_staff(): void
    {
        \App\Services\Clinic::notifyVerificationStaff('A patient is waiting.', 123);
        $this->assertDatabaseHas('notifications', ['user_id' => 2, 'queue_id' => 123, 'notification_title' => 'Verification needed']);
        $this->assertDatabaseCount('notifications', 1);
        DB::table('users')->where('user_id', 2)->update(['status' => 'inactive']);
        \App\Services\Clinic::notifyVerificationStaff('Another patient is waiting.');
        $this->assertDatabaseCount('notifications', 1);
    }

    public function test_every_role_can_update_only_their_own_phone_number(): void
    {
        foreach ([1, 2, 3, 4] as $id) {
            $original = User::findOrFail($id);
            $this->asUser($id)->postJson('/api/profile', [
                'phone_no' => '0123456789', 'user_id' => 5,
                'name' => 'Changed', 'role_id' => 4,
            ])->assertOk();
            $this->assertDatabaseHas('users', [
                'user_id' => $id, 'phone_no' => '0123456789',
                'name' => $original->name, 'role_id' => $original->role_id,
            ]);
            $this->postJson('/api/profile', ['phone_no' => str_repeat('1', 21)])->assertUnprocessable();
        }
        $this->assertDatabaseHas('users', ['user_id' => 5, 'phone_no' => null]);
    }

    public function test_patient_clinic_status_shares_counts_without_other_patient_records(): void
    {
        foreach (['waiting', 'in_consultation', 'completed', 'completed', 'cancelled'] as $i => $status) {
            DB::table('queues')->insert([
                'user_id' => 5, 'department_id' => 1, 'queue_number' => 'OTHER-'.$i,
                'queue_status' => $status, 'registered_at' => now(),
                'completed_at' => $i === 2 ? now() : ($i === 3 ? now()->subDay() : null),
            ]);
        }
        $this->asUser(1)->getJson('/api/workspace')->assertOk()
            ->assertJsonPath('clinic_status.waiting', 1)
            ->assertJsonPath('clinic_status.in_consultation', 1)
            ->assertJsonPath('clinic_status.completed_today', 1)
            ->assertJsonCount(0, 'queues');
        DB::table('queues')->delete();
        $this->getJson('/api/workspace')->assertOk()->assertJsonPath('clinic_status.waiting', 0);
    }

    public function test_admin_creation_emails_generated_password_and_edit_preserves_it(): void
    {
        config(['mail.default' => 'smtp']);
        Notification::fake();
        $data = ['name' => 'New Patient', 'email' => 'new@example.test', 'user_identifier' => 'NEW001', 'role_id' => 1, 'status' => 'active'];
        $response = $this->asUser(4)->postJson('/api/admin/users', $data)->assertOk();
        $user = User::where('user_identifier', 'NEW001')->firstOrFail();
        Notification::assertSentTo($user, \App\Notifications\TemporaryPassword::class, function ($notification) use ($user, $response) {
            $this->assertTrue(\Illuminate\Support\Facades\Hash::check($notification->temporaryPassword, $user->password));
            $this->assertStringNotContainsString($notification->temporaryPassword, $response->getContent());
            return true;
        });
        $hash = $user->password;
        $this->postJson('/api/admin/users/'.$user->user_id, [...$data, 'name' => 'Updated Patient'])->assertOk();
        $this->assertSame($hash, $user->fresh()->password);
        Notification::assertSentTimes(\App\Notifications\TemporaryPassword::class, 1);
        $this->postJson('/api/admin/users/'.$user->user_id, [...$data, 'password' => 'Override123!'])->assertUnprocessable();
    }

    public function test_account_creation_requires_email_and_rolls_back_on_delivery_failure(): void
    {
        $data = ['name' => 'New Patient', 'email' => 'new@example.test', 'user_identifier' => 'NEW001', 'role_id' => 1, 'status' => 'active'];
        config(['mail.default' => 'log']);
        $this->asUser(4)->postJson('/api/admin/users', $data)->assertStatus(503);
        $this->assertDatabaseMissing('users', ['user_identifier' => 'NEW001']);
        config(['mail.default' => 'smtp']);
        Notification::shouldReceive('send')->once()->andThrow(new \RuntimeException('Transport unavailable'));
        $this->postJson('/api/admin/users', $data)->assertStatus(503);
        $this->assertDatabaseMissing('users', ['user_identifier' => 'NEW001']);
    }

    public function test_import_preview_validates_defaults_duplicates_and_permissions_without_creating_users(): void
    {
        Notification::fake();
        $valid = ['row' => 2, 'name' => 'Student One', 'email' => 'one@example.test', 'user_identifier' => 'BATCH001'];
        $rows = [$valid,
            [...$valid, 'row' => 3, 'email' => 'other@example.test'],
            [...$valid, 'row' => 4, 'user_identifier' => 'OTHER', 'email' => 'patient@example.test'],
            [...$valid, 'row' => 5, 'email' => 'bad-email'],
            [...$valid, 'row' => 6, 'email' => 'two@example.test', 'user_identifier' => 'BATCH002', 'role' => 'not-a-role'],
        ];
        $this->asUser(1)->postJson('/api/admin/users/import/preview', ['rows' => $rows])->assertForbidden();
        $this->asUser(4)->postJson('/api/admin/users/import/preview', ['rows' => $rows])->assertOk()
            ->assertJsonPath('rows.0.status', 'ready')
            ->assertJsonPath('rows.0.data.role_id', 1)
            ->assertJsonPath('rows.0.data.status', 'active')
            ->assertJsonPath('rows.1.status', 'duplicate')
            ->assertJsonPath('rows.2.status', 'existing')
            ->assertJsonPath('rows.3.status', 'invalid')
            ->assertJsonPath('rows.4.status', 'invalid');
        $this->assertDatabaseMissing('users', ['user_identifier' => 'BATCH001']);
        Notification::assertNothingSent();
        $this->postJson('/api/admin/users/import/preview', ['rows' => array_fill(0, 501, $valid)])->assertUnprocessable();
    }

    public function test_chat_uses_only_signed_in_patient_context_and_never_sends_private_profile_fields(): void
    {
        config(['services.groq.key' => 'test-key']);
        \Illuminate\Support\Facades\Http::preventStrayRequests();
        \Illuminate\Support\Facades\Http::fake(['api.groq.com/*' => \Illuminate\Support\Facades\Http::response([
            'choices' => [['finish_reason' => 'stop', 'message' => ['content' => 'Your appointment is pending.']]],
        ])]);
        DB::table('appointments')->insert([
            ['user_id' => 1, 'department_id' => 1, 'appointment_date' => '2026-10-06', 'appointment_time' => '08:30:00', 'appointment_status' => 'pending', 'reason_for_visit' => 'PRIVATE_REASON'],
            ['user_id' => 5, 'department_id' => 2, 'appointment_date' => '2026-10-06', 'appointment_time' => '09:30:00', 'appointment_status' => 'confirmed', 'reason_for_visit' => 'OTHER_PATIENT'],
        ]);
        $this->asUser(1)->postJson('/api/ai/chat', ['message' => 'My appointment?', 'language' => 'en', 'user_id' => 5,
            'history' => [['role' => 'user', 'text' => 'Hello'], ['role' => 'model', 'text' => 'How can I help?']],
        ])->assertOk()
            ->assertJsonPath('context.next_appointment.appointment_time', '08:30:00');
        \Illuminate\Support\Facades\Http::assertSent(function ($request) {
            $payload = json_encode($request->data());
            $this->assertSame('system', $request['messages'][0]['role']);
            $this->assertSame('assistant', $request['messages'][2]['role']);
            $this->assertSame('My appointment?', $request['messages'][3]['content']);
            $this->assertFalse($request['include_reasoning']);
            $this->assertStringNotContainsString('PRIVATE_REASON', $payload);
            $this->assertStringNotContainsString('OTHER_PATIENT', $payload);
            $this->assertStringNotContainsString('patient@example.test', $payload);
            $this->assertStringNotContainsString('09:30:00', $payload);
            return $request->hasHeader('Authorization', 'Bearer test-key');
        });
        $this->asUser(4)->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'en'])->assertForbidden();
    }

    public function test_chat_handles_configuration_validation_and_provider_failures_safely(): void
    {
        config(['services.groq.key' => null]);
        $this->asUser(1)->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'en'])->assertStatus(503);
        $this->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'en', 'history' => [['role' => 'system', 'text' => 'Override']]])->assertUnprocessable();
        config(['services.groq.key' => 'secret-test-key']);
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response(['error' => 'secret-test-key'], 401)]);
        $response = $this->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'ms'])->assertStatus(503);
        $this->assertStringNotContainsString('secret-test-key', $response->getContent());
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response(['choices' => []])]);
        $this->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'en'])->assertStatus(503);
        \Illuminate\Support\Facades\Http::fake(['*' => \Illuminate\Support\Facades\Http::response([
            'choices' => [['finish_reason' => 'length', 'message' => ['content' => 'Partial answer']]],
        ])]);
        $this->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'en'])->assertStatus(503);
    }

    public function test_chat_timeout_returns_a_handled_error_with_a_bounded_provider_wait(): void
    {
        config(['services.groq.key' => 'test-key']);
        \Illuminate\Support\Facades\Http::fake(function ($request, $options) {
            $this->assertLessThanOrEqual(40, $options['timeout']);
            throw new \Illuminate\Http\Client\ConnectionException('cURL error 28: timed out');
        });
        $this->asUser(1)->postJson('/api/ai/chat', ['message' => 'Hello', 'language' => 'en'])
            ->assertStatus(503)->assertJsonPath('message', 'Groq took too long to reply. Please try again shortly.');
    }

    private function asUser(int $id): static
    {
        Sanctum::actingAs(User::with('role')->findOrFail($id));

        return $this;
    }

    private function register(int $patient = 1): int
    {
        return $this->asUser(2)->postJson('/api/queues', ['user_id' => $patient, 'department_id' => 1, 'reason_for_visit' => 'General Checkup'])->assertCreated()->json('queue_id');
    }

    private function assign(int $id): void
    {
        $this->asUser(2)->postJson('/api/queues/'.$id, ['action' => 'verify'])->assertOk();
        $this->postJson('/api/queues/'.$id, ['action' => 'assign', 'doctor_id' => 3, 'room_id' => 1])->assertOk();
    }

    public function test_registration_verification_assignment_and_consultation_lifecycle(): void
    {
        $id = $this->register();
        $this->asUser(1)->getJson('/api/workspace')->assertOk()->assertJsonPath('queues.0.queue_status', 'waiting');
        $this->postJson('/api/queues/'.$id, ['action' => 'verify'])->assertForbidden();
        $this->assign($id);
        $this->asUser(3)->postJson('/api/queues/'.$id, ['action' => 'call'])->assertOk();
        $this->postJson('/api/queues/'.$id, ['action' => 'call'])->assertUnprocessable();
        $this->postJson('/api/queues/'.$id, ['action' => 'start'])->assertOk();
        $this->travel(12)->minutes();
        $this->postJson('/api/queues/'.$id, ['action' => 'complete'])->assertOk();
        $this->assertDatabaseHas('consultations', ['queue_id' => $id, 'consultation_status' => 'completed']);
        $this->assertDatabaseHas('notifications', ['user_id' => 1, 'notification_title' => 'Your turn has been called']);
        $this->asUser(4)->getJson('/api/workspace')->assertOk()->assertJsonPath('summary.completed', 1);
        $this->getJson('/api/reports?start=2026-10-05&end=2026-10-05')->assertOk()->assertJsonPath('completed', 1);
    }

    public function test_qr_stays_valid_over_time_with_duplicate_and_patient_isolation_rules(): void
    {
        $token = $this->asUser(4)->postJson('/api/clinic/qr')->assertOk()->assertJsonPath('expires_at', null)->json('token');
        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => $token])->assertOk();
        $body = ['qr_token' => $token, 'department_id' => 1, 'reason_for_visit' => 'Follow-up Visit'];
        $this->postJson('/api/queues', $body)->assertCreated();
        $this->postJson('/api/queues', $body)->assertUnprocessable();
        $this->asUser(5)->getJson('/api/workspace')->assertOk()->assertJsonCount(0, 'queues')->assertJsonCount(0, 'notifications');
        $this->postJson('/api/notifications/1/read')->assertNotFound();
        $this->postJson('/api/queues/1', ['action' => 'cancel'])->assertForbidden();
        $this->travel(18)->months();
        $this->postJson('/api/clinic/qr/validate', ['qr_token' => $token])->assertOk();
        $this->postJson('/api/queues', $body)->assertCreated();
    }

    public function test_reading_qr_does_not_create_a_code_before_admin_setup(): void
    {
        foreach ([2, 4, 2] as $userId) {
            $this->asUser($userId)->getJson('/api/clinic/qr')->assertOk()->assertExactJson(['token' => null, 'expires_at' => null]);
        }
        $this->assertDatabaseHas('clinic_settings', ['id' => 1, 'qr_token' => null, 'qr_expires_at' => null]);
        $this->assertDatabaseCount('audit_logs', 0);
        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => 'unknown-code'])->assertUnprocessable();
    }

    public function test_every_staff_member_reads_the_same_persisted_qr_without_rotating_it(): void
    {
        $secondStaff = User::create(['role_id' => 2, 'user_identifier' => 'STAFF002', 'name' => 'Second Staff',
            'email' => 'staff2@example.test', 'password' => 'TestPassword123!', 'status' => 'active']);
        $token = $this->asUser(4)->postJson('/api/clinic/qr')->assertOk()->json('token');

        foreach ([2, $secondStaff->user_id, 4, 2] as $userId) {
            $this->asUser($userId)->getJson('/api/clinic/qr')->assertOk()->assertExactJson(['token' => $token, 'expires_at' => null]);
        }
        $this->assertDatabaseHas('clinic_settings', ['id' => 1, 'qr_token' => $token, 'qr_expires_at' => null]);
        $this->assertDatabaseCount('audit_logs', 1);
        $this->assertDatabaseHas('audit_logs', ['actor_id' => 4, 'action' => 'create_qr', 'record_type' => 'clinic']);
    }

    public function test_only_administrators_can_create_or_replace_the_clinic_qr(): void
    {
        $this->asUser(2)->postJson('/api/clinic/qr')->assertForbidden();
        $this->assertDatabaseHas('clinic_settings', ['id' => 1, 'qr_token' => null]);
        $token = $this->asUser(4)->postJson('/api/clinic/qr')->assertOk()->json('token');

        foreach ([2, 1, 3] as $userId) {
            $this->asUser($userId)->postJson('/api/clinic/qr')->assertForbidden();
            $this->assertDatabaseHas('clinic_settings', ['id' => 1, 'qr_token' => $token]);
        }
        foreach ([1, 3] as $userId) {
            $this->asUser($userId)->getJson('/api/clinic/qr')->assertForbidden();
        }
        $this->assertDatabaseCount('audit_logs', 1);
    }

    public function test_admin_replacement_invalidates_previous_qr_for_validation_and_registration(): void
    {
        $oldToken = $this->asUser(4)->postJson('/api/clinic/qr')->assertOk()->json('token');
        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => $oldToken])->assertOk();
        $newToken = $this->asUser(4)->postJson('/api/clinic/qr')->assertOk()->assertJsonPath('expires_at', null)->json('token');
        $this->assertNotSame($oldToken, $newToken);
        $this->assertDatabaseHas('audit_logs', ['actor_id' => 4, 'action' => 'replace_qr', 'record_type' => 'clinic']);
        $this->asUser(2)->getJson('/api/clinic/qr')->assertOk()->assertJsonPath('token', $newToken);

        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => $oldToken])->assertUnprocessable();
        $body = ['department_id' => 1, 'reason_for_visit' => 'Follow-up Visit'];
        $this->postJson('/api/queues', $body + ['qr_token' => $oldToken])->assertUnprocessable();
        $this->assertDatabaseCount('queues', 0);
        $this->postJson('/api/clinic/qr/validate', ['qr_token' => $newToken])->assertOk();
        $this->postJson('/api/queues', $body + ['qr_token' => $newToken])->assertCreated();
    }

    public function test_legacy_expired_qr_is_preserved_and_works_as_a_static_code(): void
    {
        $token = Crypt::encryptString('legacy-clinic-qr-token');
        DB::table('clinic_settings')->where('id', 1)->update(['qr_token' => $token, 'qr_expires_at' => now()->subMonths(6)]);
        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => $token])->assertOk();

        $migration = require database_path('migrations/2026_10_05_000002_make_clinic_qr_static.php');
        $migration->up();

        $this->assertDatabaseHas('clinic_settings', ['id' => 1, 'qr_token' => $token, 'qr_expires_at' => null]);
        $this->asUser(2)->getJson('/api/clinic/qr')->assertOk()->assertExactJson(['token' => $token, 'expires_at' => null]);
        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => $token])->assertOk();
        $this->postJson('/api/queues', ['qr_token' => $token, 'department_id' => 1, 'reason_for_visit' => 'General Checkup'])->assertCreated();
    }

    public function test_static_qr_migration_leaves_unconfigured_clinic_for_administrator_setup(): void
    {
        $migration = require database_path('migrations/2026_10_05_000002_make_clinic_qr_static.php');
        $migration->up();

        $this->assertDatabaseHas('clinic_settings', ['id' => 1, 'qr_token' => null, 'qr_expires_at' => null]);
    }

    public function test_staff_cannot_assign_wrong_department_or_unverified_queue(): void
    {
        $id = $this->register();
        $body = ['action' => 'assign', 'doctor_id' => 3, 'room_id' => 1];
        $this->postJson('/api/queues/'.$id, $body)->assertUnprocessable();
        $this->postJson('/api/queues/'.$id, ['action' => 'verify'])->assertOk();
        DB::table('rooms')->where('room_id', 1)->update(['department_id' => 2]);
        $this->postJson('/api/queues/'.$id, $body)->assertUnprocessable();
        DB::table('rooms')->where('room_id', 1)->update(['department_id' => 1]);
        $this->postJson('/api/queues/'.$id, $body)->assertOk();
        $this->asUser(4)->postJson('/api/admin/rooms/1', ['room_name' => 'New Room', 'department_id' => 1, 'doctor_id' => 3, 'status' => 'inactive'])->assertUnprocessable();
    }

    public function test_queue_order_busy_doctor_skip_requeue_and_absent(): void
    {
        $first = $this->register();
        $second = $this->register(5);
        $this->assign($first);
        $this->assign($second);
        $this->asUser(3)->postJson('/api/queues/'.$second, ['action' => 'call'])->assertUnprocessable();
        $this->postJson('/api/queues/'.$first, ['action' => 'call'])->assertOk();
        $this->postJson('/api/queues/'.$second, ['action' => 'call'])->assertUnprocessable();
        $this->postJson('/api/queues/'.$first, ['action' => 'skip'])->assertOk();
        $this->asUser(2)->postJson('/api/queues/'.$first, ['action' => 'requeue'])->assertOk();
        $this->postJson('/api/queues/'.$second, ['action' => 'priority', 'priority' => 2, 'priority_note' => 'Staff reviewed urgent request'])->assertOk();
        $this->assertDatabaseHas('priority_training_samples', ['queue_id' => $second, 'priority' => 2, 'reviewed_by' => 2]);
        $this->asUser(3)->postJson('/api/queues/'.$second, ['action' => 'call'])->assertOk();
        $this->postJson('/api/queues/'.$second, ['action' => 'absent'])->assertOk();
    }

    public function test_appointment_capacity_doctor_and_reminder_rules(): void
    {
        DB::table('clinic_settings')->where('id', 1)->update(['slot_capacity' => 1]);
        $slots = $this->asUser(1)->getJson('/api/appointments/slots?department_id=1&date=2026-10-06&doctor_id=3')->assertOk()->json('slots');
        $this->assertContains('08:00', $slots);
        $body = ['department_id' => 1, 'doctor_id' => 3, 'appointment_date' => '2026-10-06', 'appointment_time' => '08:00', 'reason_for_visit' => 'Checkup'];
        $this->postJson('/api/appointments', $body)->assertCreated();
        $this->asUser(5)->postJson('/api/appointments', $body)->assertUnprocessable();
        $this->postJson('/api/appointments', array_replace($body, ['department_id' => 2, 'appointment_time' => '09:00']))->assertUnprocessable();
        ClinicNotifications::refresh();
        $this->assertEquals(0, DB::table('notifications')->where('notification_title', 'Appointment reminder')->count());
        $this->asUser(2)->postJson('/api/appointments/1/verify')->assertOk();
        ClinicNotifications::refresh();
        ClinicNotifications::refresh();
        $this->assertEquals(1, DB::table('notifications')->where('notification_title', 'Appointment reminder')->count());
        $this->asUser(5)->postJson('/api/appointments/1/cancel')->assertNotFound();
        $this->asUser(1)->postJson('/api/appointments/1/cancel')->assertOk();
        $this->postJson('/api/appointments', array_replace($body, ['appointment_date' => '2026-10-10']))->assertUnprocessable();
    }

    public function test_appointments_require_staff_verification_before_confirmation_and_check_in(): void
    {
        $body = ['department_id' => 1, 'doctor_id' => 3, 'appointment_date' => '2026-10-05', 'appointment_time' => '10:00', 'reason_for_visit' => 'Checkup', 'appointment_status' => 'confirmed'];
        $id = $this->asUser(1)->postJson('/api/appointments', $body)->assertCreated()->assertJsonPath('appointment_status', 'pending')->json('appointment_id');
        $this->assertDatabaseHas('appointments', ['appointment_id' => $id, 'appointment_status' => 'pending']);
        $this->assertDatabaseMissing('notifications', ['notification_title' => 'Appointment confirmed']);
        $this->asUser(2)->getJson('/api/workspace')->assertOk()->assertJsonPath('appointments.0.appointment_status', 'pending')->assertJsonPath('appointments.0.user_identifier', 'PATIENT001');
        $this->asUser(5)->getJson('/api/workspace')->assertOk()->assertJsonCount(0, 'appointments');
        foreach ([1, 3, 4, 5] as $userId) {
            $this->asUser($userId)->postJson('/api/appointments/'.$id.'/verify')->assertForbidden();
        }
        $token = $this->asUser(4)->postJson('/api/clinic/qr')->assertOk()->json('token');
        $checkIn = ['department_id' => 1, 'appointment_id' => $id, 'reason_for_visit' => 'Checkup', 'qr_token' => $token];
        $this->asUser(1)->postJson('/api/queues', $checkIn)->assertUnprocessable();
        $this->asUser(2)->postJson('/api/queues', $checkIn + ['user_id' => 1])->assertUnprocessable();
        $this->postJson('/api/appointments/'.$id.'/verify')->assertOk()->assertJsonPath('appointment_status', 'confirmed');
        $this->postJson('/api/appointments/'.$id.'/verify')->assertUnprocessable();
        $this->assertDatabaseHas('audit_logs', ['actor_id' => 2, 'action' => 'verify_appointment', 'record_id' => $id]);
        $this->assertEquals(1, DB::table('notifications')->where('notification_title', 'Appointment confirmed')->count());
        $this->asUser(1)->getJson('/api/workspace')->assertOk()->assertJsonPath('appointments.0.appointment_status', 'confirmed');
        $this->postJson('/api/queues', $checkIn)->assertCreated();
        $this->assertDatabaseHas('queues', ['appointment_id' => $id, 'queue_status' => 'waiting']);
    }

    public function test_cancelled_past_and_unavailable_appointments_cannot_be_verified(): void
    {
        $body = ['department_id' => 1, 'doctor_id' => 3, 'appointment_date' => '2026-10-05', 'appointment_time' => '10:00', 'reason_for_visit' => 'Checkup'];
        $id = $this->asUser(1)->postJson('/api/appointments', $body)->assertCreated()->json('appointment_id');
        DB::table('rooms')->where('room_id', 1)->update(['status' => 'inactive']);
        $this->asUser(2)->postJson('/api/appointments/'.$id.'/verify')->assertUnprocessable();
        DB::table('rooms')->where('room_id', 1)->update(['status' => 'available']);
        $this->travel(3)->hours();
        $this->postJson('/api/appointments/'.$id.'/verify')->assertUnprocessable();
        $this->asUser(1)->postJson('/api/appointments/'.$id.'/cancel')->assertOk();
        $this->asUser(2)->postJson('/api/appointments/'.$id.'/verify')->assertUnprocessable();
        $this->postJson('/api/appointments/999/verify')->assertNotFound();
        $this->assertDatabaseMissing('audit_logs', ['action' => 'verify_appointment']);
    }

    public function test_upgrade_returns_only_upcoming_auto_confirmed_unchecked_bookings_to_pending(): void
    {
        $base = ['user_id' => 1, 'department_id' => 1, 'appointment_date' => '2026-10-06', 'appointment_time' => '10:00:00', 'appointment_status' => 'confirmed', 'reason_for_visit' => 'Checkup'];
        foreach (range(1, 6) as $id) {
            DB::table('appointments')->insert($base + ['appointment_id' => $id]);
            if ($id !== 2) {
                DB::table('audit_logs')->insert(['actor_id' => 1, 'action' => 'book_appointment', 'record_type' => 'appointment', 'record_id' => $id]);
            }
        }
        DB::table('audit_logs')->insert(['actor_id' => 2, 'action' => 'verify_appointment', 'record_type' => 'appointment', 'record_id' => 3]);
        DB::table('queues')->insert(['user_id' => 1, 'department_id' => 1, 'appointment_id' => 4, 'queue_status' => 'waiting']);
        DB::table('appointments')->where('appointment_id', 5)->update(['appointment_date' => '2026-10-04']);
        DB::table('appointments')->where('appointment_id', 6)->update(['appointment_status' => 'cancelled']);
        $migration = require database_path('migrations/2026_10_05_000003_require_appointment_verification.php');
        $migration->up();
        $migration->up();
        $this->assertDatabaseHas('appointments', ['appointment_id' => 1, 'appointment_status' => 'pending']);
        foreach ([2, 3, 4, 5] as $id) {
            $this->assertDatabaseHas('appointments', ['appointment_id' => $id, 'appointment_status' => 'confirmed']);
        }
        $this->assertDatabaseHas('appointments', ['appointment_id' => 6, 'appointment_status' => 'cancelled']);
        $this->assertEquals(1, DB::table('notifications')->where('notification_title', 'Appointment awaiting verification')->count());
    }

    public function test_admin_management_and_role_enforcement(): void
    {
        $body = ['department_name' => 'Pharmacy', 'department_code' => 'PH', 'status' => 'active'];
        $this->asUser(1)->postJson('/api/admin/departments', $body)->assertForbidden();
        $this->asUser(4)->postJson('/api/admin/departments', $body)->assertOk();
        $this->postJson('/api/admin/rooms', ['room_name' => 'Consultation Room 2', 'room_number' => 'R102', 'department_id' => 1, 'doctor_id' => 3, 'status' => 'available'])->assertOk();
        $this->assertDatabaseHas('rooms', ['room_number' => 'R102']);
        $admin = User::find(4);
        $this->postJson('/api/admin/users/4', ['name' => $admin->name, 'email' => $admin->email, 'user_identifier' => $admin->user_identifier, 'role_id' => 4, 'status' => 'inactive'])->assertUnprocessable();
        $this->getJson('/api/reports?start=2026-10-06&end=2026-10-05')->assertUnprocessable();
        $this->postJson('/api/admin/settings', ['average_minutes' => 15, 'slot_minutes' => 30, 'slot_capacity' => 4, 'opening_time' => '08:00', 'closing_time' => '17:00', 'registration_open' => false])->assertOk();
        $this->asUser(2)->postJson('/api/queues', ['user_id' => 1, 'department_id' => 1, 'reason_for_visit' => 'Checkup'])->assertUnprocessable();
    }

    public function test_password_reset_is_single_use_and_revokes_sessions(): void
    {
        Notification::fake();
        $user = User::find(1);
        $user->createToken('existing');
        $this->postJson('/api/forgot-password', ['email' => $user->email])->assertOk();
        $token = null;
        Notification::assertSentTo($user, ResetPassword::class, function ($notification) use (&$token) {
            $token = $notification->token;

            return true;
        });
        $this->get('/reset-password/'.$token.'?email='.urlencode($user->email))->assertOk();
        $payload = ['email' => $user->email, 'token' => $token, 'password' => 'Replacement123!', 'password_confirmation' => 'Replacement123!'];
        $this->post('/reset-password', $payload)->assertSessionHasNoErrors()->assertSessionHas('status');
        $this->assertDatabaseCount('personal_access_tokens',0);
        $this->post('/reset-password',$payload)->assertSessionHasErrors('email');
        $this->postJson('/api/login',['user_identifier' => $user->user_identifier, 'password' => 'Replacement123!'])->assertOk();
    }
}
