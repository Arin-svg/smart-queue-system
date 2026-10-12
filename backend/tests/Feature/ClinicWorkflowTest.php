<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\ClinicNotifications;
use Carbon\Carbon;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
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

    public function test_qr_expiry_duplicates_and_patient_isolation(): void
    {
        $token = $this->asUser(2)->postJson('/api/clinic/qr')->assertOk()->json('token');
        $this->asUser(1)->postJson('/api/clinic/qr/validate', ['qr_token' => $token])->assertOk();
        $body = ['qr_token' => $token, 'department_id' => 1, 'reason_for_visit' => 'Follow-up Visit'];
        $this->postJson('/api/queues', $body)->assertCreated();
        $this->postJson('/api/queues', $body)->assertUnprocessable();
        $this->asUser(5)->getJson('/api/workspace')->assertOk()->assertJsonCount(0, 'queues')->assertJsonCount(0, 'notifications');
        $this->postJson('/api/notifications/1/read')->assertNotFound();
        $this->postJson('/api/queues/1', ['action' => 'cancel'])->assertForbidden();
        $this->travel(16)->minutes();
        $this->postJson('/api/clinic/qr/validate', ['qr_token' => $token])->assertUnprocessable();
        $this->postJson('/api/queues', $body)->assertUnprocessable();
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
        ClinicNotifications::refresh();
        $this->assertEquals(1, DB::table('notifications')->where('notification_title', 'Appointment reminder')->count());
        $this->postJson('/api/appointments/1/cancel')->assertNotFound();
        $this->asUser(1)->postJson('/api/appointments/1/cancel')->assertOk();
        $this->postJson('/api/appointments', array_replace($body, ['appointment_date' => '2026-10-10']))->assertUnprocessable();
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
