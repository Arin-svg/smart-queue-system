<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('rooms')) {
            Schema::table('rooms', fn (Blueprint $t) => $t->string('room_number', 30)->nullable());
        }
        if (Schema::hasTable('departments')) {
            foreach (DB::table('departments')->whereNull('department_code')->get() as $d) {
                DB::table('departments')->where('department_id', $d->department_id)->update(['department_code' => 'D'.$d->department_id]);
            }
        }
        Schema::create('priority_training_samples', function (Blueprint $t) {
            $t->id();
            $t->unsignedInteger('queue_id')->unique();
            $t->unsignedInteger('department_id');
            $t->string('reason_for_visit', 255);
            $t->string('queue_type', 30);
            $t->unsignedInteger('wait_minutes');
            $t->unsignedTinyInteger('priority');
            $t->unsignedInteger('reviewed_by');
            $t->timestamp('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('priority_training_samples');
        if (Schema::hasColumn('rooms', 'room_number')) {
            Schema::table('rooms', fn (Blueprint $t) => $t->dropColumn('room_number'));
        }
    }
};
