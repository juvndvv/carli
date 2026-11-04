<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('health.whoop_accounts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->bigInteger('whoop_user_id')->unique();
            $table->text('email')->nullable();
            $table->text('access_token')->nullable();
            $table->text('refresh_token');
            $table->timestampTz('token_expires_at')->nullable();
            $table->text('status')->default('active');
            $table->text('last_error')->nullable();
            $table->timestampTz('synced_at')->nullable();
            $table->timestampsTz();
        });
        DB::statement("ALTER TABLE health.whoop_accounts ADD CONSTRAINT whoop_accounts_status_check CHECK (status IN ('active','reconnect'))");

        // Every record keeps WHOOP's whole JSON in payload, so new fields can be read later without a resync.
        Schema::create('health.whoop_cycles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->bigInteger('whoop_id');
            $table->timestampTz('starts_at');
            // The cycle in progress has no end yet.
            $table->timestampTz('ends_at')->nullable();
            // The day the cycle starts on, in the band's own time zone.
            $table->date('day');
            $table->text('score_state');
            $table->decimal('strain', 5, 2)->nullable();
            $table->decimal('kilojoule', 10, 2)->nullable();
            $table->smallInteger('average_heart_rate')->nullable();
            $table->smallInteger('max_heart_rate')->nullable();
            // Steps over the whole cycle (wake to wake, not midnight to midnight); null when the band was not worn.
            $table->integer('step_count')->nullable();
            $table->jsonb('payload');
            $table->timestampsTz();

            $table->unique(['user_id', 'whoop_id']);
            $table->index(['user_id', 'day']);
        });

        Schema::create('health.whoop_recoveries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->bigInteger('cycle_whoop_id');
            $table->uuid('sleep_whoop_id');
            $table->text('score_state');
            $table->boolean('calibrating')->default(false);
            $table->smallInteger('recovery_score')->nullable();
            $table->smallInteger('resting_heart_rate')->nullable();
            $table->decimal('hrv_rmssd_milli', 7, 3)->nullable();
            $table->decimal('spo2_percentage', 5, 2)->nullable();
            $table->decimal('skin_temp_celsius', 5, 2)->nullable();
            $table->jsonb('payload');
            $table->timestampsTz();

            $table->unique(['user_id', 'cycle_whoop_id']);
            $table->unique(['user_id', 'sleep_whoop_id']);
        });

        Schema::create('health.whoop_sleeps', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('whoop_id');
            $table->bigInteger('cycle_whoop_id')->nullable();
            $table->timestampTz('starts_at');
            $table->timestampTz('ends_at');
            $table->date('day');
            $table->boolean('nap')->default(false);
            $table->text('score_state');
            $table->integer('in_bed_milli')->nullable();
            $table->integer('awake_milli')->nullable();
            $table->integer('light_milli')->nullable();
            $table->integer('deep_milli')->nullable();
            $table->integer('rem_milli')->nullable();
            $table->smallInteger('disturbances')->nullable();
            $table->decimal('respiratory_rate', 5, 2)->nullable();
            $table->smallInteger('performance_percentage')->nullable();
            $table->smallInteger('consistency_percentage')->nullable();
            $table->decimal('efficiency_percentage', 5, 2)->nullable();
            $table->integer('need_milli')->nullable();
            $table->jsonb('payload');
            $table->timestampsTz();

            $table->unique(['user_id', 'whoop_id']);
            $table->index(['user_id', 'day']);
        });

        Schema::create('health.whoop_workouts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('whoop_id');
            $table->timestampTz('starts_at');
            $table->timestampTz('ends_at');
            $table->date('day');
            $table->text('sport_name')->nullable();
            $table->text('score_state');
            $table->decimal('strain', 5, 2)->nullable();
            $table->decimal('kilojoule', 10, 2)->nullable();
            $table->smallInteger('average_heart_rate')->nullable();
            $table->smallInteger('max_heart_rate')->nullable();
            $table->decimal('distance_meter', 10, 2)->nullable();
            // Milliseconds in heart rate zones 0 to 5.
            $table->jsonb('zone_durations')->nullable();
            $table->jsonb('payload');
            $table->timestampsTz();

            $table->unique(['user_id', 'whoop_id']);
            $table->index(['user_id', 'day']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('health.whoop_workouts');
        Schema::dropIfExists('health.whoop_sleeps');
        Schema::dropIfExists('health.whoop_recoveries');
        Schema::dropIfExists('health.whoop_cycles');
        Schema::dropIfExists('health.whoop_accounts');
    }
};
