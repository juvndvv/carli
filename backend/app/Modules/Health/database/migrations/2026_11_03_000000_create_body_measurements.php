<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Where on the body a tape measurement is taken: the zone places it on the body viewer.
        Schema::create('health.body_sites', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->text('zone');
            $table->text('side')->nullable();
            $table->integer('position')->default(0);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'position']);
        });
        DB::statement("ALTER TABLE health.body_sites ADD CONSTRAINT body_sites_zone_check CHECK (zone IN ('neck','shoulders','chest','arm','forearm','wrist','waist','abdomen','hips','thigh','calf','ankle'))");
        DB::statement("ALTER TABLE health.body_sites ADD CONSTRAINT body_sites_side_check CHECK (side IS NULL OR side IN ('left','right'))");

        Schema::create('health.body_measurements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('site_id')->constrained('health.body_sites')->cascadeOnDelete();
            $table->timestampTz('measured_at');
            $table->decimal('value_cm', 5, 1);
            $table->timestampsTz();

            $table->index(['site_id', 'measured_at']);
            $table->index(['user_id', 'measured_at']);
        });
        DB::statement('ALTER TABLE health.body_measurements ADD CONSTRAINT body_measurements_value_check CHECK (value_cm > 0 AND value_cm < 400)');
    }

    public function down(): void
    {
        Schema::dropIfExists('health.body_measurements');
        Schema::dropIfExists('health.body_sites');
    }
};
