<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE SCHEMA IF NOT EXISTS health');

        Schema::create('health.measurements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestampTz('measured_at');
            $table->decimal('weight_kg', 6, 2);
            $table->text('source');
            // What the scale itself worked out (0x24 frame); null for manual entries.
            $table->decimal('bmi', 4, 1)->nullable();
            $table->decimal('fat_percent', 4, 1)->nullable();
            $table->decimal('muscle_percent', 4, 1)->nullable();
            $table->decimal('water_percent', 4, 1)->nullable();
            $table->smallInteger('visceral_or_bone')->nullable();
            $table->integer('basal_kcal')->nullable();
            // Raw data, kept so everything can be decoded again later.
            $table->jsonb('impedances')->nullable();
            $table->text('frames')->nullable();
            $table->text('metrics_frame')->nullable();
            $table->text('device')->nullable();
            $table->text('firmware')->nullable();
            // Weight + impedances: the same weigh-in arrives live and again from the scale's history.
            $table->text('fingerprint')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'measured_at']);
            $table->unique(['user_id', 'fingerprint']);
        });
        DB::statement("ALTER TABLE health.measurements ADD CONSTRAINT measurements_source_check CHECK (source IN ('scale','manual'))");
        DB::statement('ALTER TABLE health.measurements ADD CONSTRAINT measurements_weight_check CHECK (weight_kg > 0 AND weight_kg < 400)');
    }

    public function down(): void
    {
        DB::statement('DROP SCHEMA IF EXISTS health CASCADE');
    }
};
