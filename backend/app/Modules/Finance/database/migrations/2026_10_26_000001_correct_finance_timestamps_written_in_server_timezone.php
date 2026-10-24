<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $sessionTimezone = (string) config('database.connections.pgsql.timezone');
        $serverDefault = (array) DB::selectOne("SELECT reset_val FROM pg_settings WHERE name = 'TimeZone'");
        $writtenAs = is_string($serverDefault['reset_val'] ?? null) ? $serverDefault['reset_val'] : null;

        if ($writtenAs === null || $sessionTimezone === '' || $this->sameOffsets($writtenAs, $sessionTimezone)) {
            return;
        }

        $columns = DB::select(
            "SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'finance' AND data_type = 'timestamp with time zone'"
        );

        foreach ($columns as $column) {
            DB::statement(sprintf(
                'UPDATE finance.%1$s SET %2$s = (%2$s AT TIME ZONE ?) AT TIME ZONE ? WHERE %2$s IS NOT NULL',
                '"'.$column->table_name.'"',
                '"'.$column->column_name.'"',
            ), [$writtenAs, $sessionTimezone]);
        }
    }

    public function down(): void {}

    private function sameOffsets(string $left, string $right): bool
    {
        $row = DB::selectOne(
            "SELECT bool_and((d AT TIME ZONE ?) = (d AT TIME ZONE ?)) AS same FROM (VALUES (timestamptz '2026-01-15 12:00:00+00'), (timestamptz '2026-07-15 12:00:00+00')) AS samples(d)",
            [$left, $right],
        );

        return ((array) $row)['same'] ?? false;
    }
};
