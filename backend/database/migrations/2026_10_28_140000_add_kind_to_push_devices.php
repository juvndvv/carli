<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('push_devices', function (Blueprint $table) {
            $table->string('kind', 16)->default('app')->after('environment');
        });
    }

    public function down(): void
    {
        Schema::table('push_devices', function (Blueprint $table) {
            $table->dropColumn('kind');
        });
    }
};
