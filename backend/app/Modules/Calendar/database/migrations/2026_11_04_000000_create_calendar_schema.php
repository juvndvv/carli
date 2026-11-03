<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE SCHEMA IF NOT EXISTS calendar');

        Schema::create('calendar.google_accounts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            // The primary calendar's id, which Google sets to the account's address.
            $table->text('email');
            $table->text('access_token')->nullable();
            $table->text('refresh_token');
            $table->timestampTz('token_expires_at')->nullable();
            $table->text('status')->default('active');
            $table->text('last_error')->nullable();
            $table->timestampTz('synced_at')->nullable();
            $table->timestampsTz();

            $table->unique(['user_id', 'email']);
        });
        DB::statement("ALTER TABLE calendar.google_accounts ADD CONSTRAINT google_accounts_status_check CHECK (status IN ('active','reconnect'))");

        Schema::create('calendar.google_calendars', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('account_id')->constrained('calendar.google_accounts')->cascadeOnDelete();
            $table->text('google_id');
            $table->text('name');
            $table->text('color')->nullable();
            $table->boolean('primary')->default(false);
            $table->boolean('selected')->default(true);
            $table->integer('sort')->default(0);
            $table->timestampsTz();

            $table->unique(['account_id', 'google_id']);
        });

        Schema::create('calendar.events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('calendar_id')->constrained('calendar.google_calendars')->cascadeOnDelete();
            // One row per instance: recurring events arrive expanded (singleEvents=true).
            $table->text('google_id');
            $table->text('title');
            $table->text('location')->nullable();
            $table->text('description')->nullable();
            $table->boolean('all_day')->default(false);
            // Timed events keep the instant; all-day ones only the days (end exclusive, as Google sends it).
            $table->timestampTz('starts_at')->nullable();
            $table->timestampTz('ends_at')->nullable();
            $table->date('start_date');
            $table->date('end_date');
            $table->text('html_link')->nullable();
            $table->text('meet_link')->nullable();
            $table->timestampsTz();

            $table->unique(['calendar_id', 'google_id']);
            $table->index(['user_id', 'start_date']);
            $table->index(['user_id', 'end_date']);
        });
    }

    public function down(): void
    {
        DB::statement('DROP SCHEMA IF EXISTS calendar CASCADE');
    }
};
