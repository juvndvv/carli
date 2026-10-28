<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('finance.accounts', function (Blueprint $table) {
            $table->smallInteger('ownership_percent')->default(100);
        });
        DB::statement('ALTER TABLE finance.accounts ADD CONSTRAINT accounts_ownership_percent_check CHECK (ownership_percent BETWEEN 1 AND 100)');
    }

    public function down(): void
    {
        Schema::table('finance.accounts', function (Blueprint $table) {
            $table->dropColumn('ownership_percent');
        });
    }
};
