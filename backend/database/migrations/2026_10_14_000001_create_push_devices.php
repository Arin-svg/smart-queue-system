<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
 public function up(): void { Schema::create('push_devices', function(Blueprint $t) {
  $t->id(); $t->unsignedBigInteger('user_id')->index(); $t->unsignedBigInteger('access_token_id');
  $t->string('token_hash',64)->unique(); $t->text('token'); $t->unsignedBigInteger('last_notification_id')->default(0); $t->timestamps();
 }); }
 public function down(): void { Schema::dropIfExists('push_devices'); }
};
