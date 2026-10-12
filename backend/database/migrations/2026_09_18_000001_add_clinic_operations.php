<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void {
        // Domain tables already exist in MySQL. Tests create their own equivalent schema.
        if (Schema::hasTable('departments')) {
            Schema::table('departments', fn (Blueprint $t) => $t->string('department_code', 12)->nullable()->unique());
            Schema::table('rooms', function (Blueprint $t) { $t->unsignedInteger('doctor_id')->nullable(); $t->foreign('doctor_id')->references('user_id')->on('users'); });
            Schema::table('queues', function (Blueprint $t) { $t->unsignedTinyInteger('priority')->default(0); $t->string('priority_note', 255)->nullable(); });
        }
        Schema::create('clinic_settings', function (Blueprint $t) {
            $t->unsignedInteger('id')->primary();
            $t->unsignedInteger('average_minutes')->default(15);
            $t->unsignedInteger('slot_minutes')->default(30);
            $t->string('opening_time', 5)->default('08:00');
            $t->string('closing_time', 5)->default('17:00');
            $t->unsignedInteger('slot_capacity')->default(4);
            $t->boolean('registration_open')->default(true);
            $t->text('qr_token')->nullable();
            $t->timestamp('qr_expires_at')->nullable();
        });
        DB::table('clinic_settings')->insert(['id' => 1]);
        Schema::create('audit_logs', function (Blueprint $t) {
            $t->id(); $t->unsignedInteger('actor_id')->nullable();
            $t->string('action', 80); $t->string('record_type', 40);
            $t->unsignedInteger('record_id')->nullable();
            $t->text('details')->nullable(); $t->timestamp('created_at')->useCurrent();
        });
        Schema::create('password_reset_tokens', function (Blueprint $t) {
            $t->string('email')->primary(); $t->string('token'); $t->timestamp('created_at')->nullable();
        });
    }
    public function down(): void {
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('clinic_settings');
        if (Schema::hasColumn('queues', 'priority')) {
            Schema::table('queues', fn (Blueprint $t) => $t->dropColumn(['priority', 'priority_note']));
            Schema::table('rooms', function (Blueprint $t) { $t->dropForeign(['doctor_id']); $t->dropColumn('doctor_id'); });
            Schema::table('departments', fn (Blueprint $t) => $t->dropColumn('department_code'));
        }
    }
};
