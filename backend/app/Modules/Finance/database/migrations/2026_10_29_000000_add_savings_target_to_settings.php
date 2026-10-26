<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('finance.settings', function (Blueprint $table) {
            $table->smallInteger('savings_target_percent')->default(20);
        });
        DB::statement('ALTER TABLE finance.settings ADD CONSTRAINT settings_savings_target_check CHECK (savings_target_percent BETWEEN 1 AND 100)');
    }

    public function down(): void
    {
        Schema::table('finance.settings', function (Blueprint $table) {
            $table->dropColumn('savings_target_percent');
        });
    }
};
