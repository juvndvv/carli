<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Weigh-ins saved before the UTC fix were stored one hour early (UTC wall time read as Madrid).
 * Only the rows from the first day exist; later saves convert the zone first.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::update("UPDATE health.measurements SET measured_at = (measured_at AT TIME ZONE 'Europe/Madrid') AT TIME ZONE 'UTC' WHERE created_at < now()");
    }

    public function down(): void
    {
        DB::update("UPDATE health.measurements SET measured_at = (measured_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Madrid'");
    }
};
