<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tasks.tasks', function (Blueprint $table) {
            // When the push for the task's due time went out; cleared when the date or time changes.
            $table->timestampTz('reminded_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('tasks.tasks', function (Blueprint $table) {
            $table->dropColumn('reminded_at');
        });
    }
};
