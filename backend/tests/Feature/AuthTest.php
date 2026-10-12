<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Schema::create('roles', function (Blueprint $table) {
            $table->increments('role_id');
            $table->string('role_name');
        });
        Schema::create('users', function (Blueprint $table) {
            $table->increments('user_id');
            $table->unsignedInteger('role_id');
            $table->string('user_identifier')->unique();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->string('status')->default('active');
            $table->rememberToken();
            $table->timestamps();
        });
        DB::table('roles')->insert(['role_id' => 1, 'role_name' => 'patient']);
        User::create(['role_id' => 1, 'user_identifier' => 'CB23094', 'name' => 'Test Patient',
            'email' => 'patient@example.test', 'password' => 'TestPassword123!', 'status' => 'active']);
    }

    public function test_login_me_and_logout_revoke_the_token(): void
    {
        $login = $this->postJson('/api/login', ['user_identifier' => 'CB23094', 'password' => 'TestPassword123!'])
            ->assertOk()->assertJsonPath('user.role', 'patient')->assertJsonMissingPath('user.password');
        $headers = ['Authorization' => 'Bearer '.$login->json('token')];
        $this->getJson('/api/me', $headers)->assertOk()->assertJsonPath('user.id', 1);
        $this->postJson('/api/logout', [], $headers)->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/me', $headers)->assertUnauthorized();
    }

    public function test_invalid_and_inactive_accounts_cannot_login(): void
    {
        $this->postJson('/api/login', ['user_identifier' => 'CB23094', 'password' => 'wrong'])->assertUnauthorized();
        $this->postJson('/api/login', ['user_identifier' => 'unknown', 'password' => 'wrong'])->assertUnauthorized();
        User::first()->update(['status' => 'inactive']);
        $this->postJson('/api/login', ['user_identifier' => 'CB23094', 'password' => 'TestPassword123!'])->assertUnauthorized();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_inactive_existing_session_is_denied(): void
    {
        $token = User::first()->createToken('test')->plainTextToken;
        User::first()->update(['status' => 'inactive']);
        $this->getJson('/api/me', ['Authorization' => 'Bearer '.$token])->assertForbidden();
    }

    public function test_validation_throttling_and_reset_request(): void
    {
        $this->postJson('/api/login', [])->assertUnprocessable();
        $this->postJson('/api/forgot-password', ['email' => 'bad'])->assertUnprocessable();
        Notification::fake();
        $this->postJson('/api/forgot-password', ['email' => 'patient@example.test'])->assertOk();
        Notification::assertSentTo(User::first(), ResetPassword::class);
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/login', ['user_identifier' => 'bad', 'password' => 'bad'])->assertUnauthorized();
        }
        $this->postJson('/api/login', ['user_identifier' => 'bad', 'password' => 'bad'])->assertStatus(429);
    }
}
