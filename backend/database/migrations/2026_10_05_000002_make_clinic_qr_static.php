<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Preserve the exact existing code so printed copies remain usable.
        DB::table('clinic_settings')->where('id', 1)->update(['qr_expires_at' => null]);
    }

    public function down(): void
    {
        // A previous expiry cannot be recovered; leave the clinic code intact.
    }
};
