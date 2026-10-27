<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('notification_preferences')->update(['push' => true, 'in_app' => true]);
    }

    public function down(): void {}
};
