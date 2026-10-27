<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE SCHEMA IF NOT EXISTS habits');

        Schema::create('habits.habits', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->text('icon');
            $table->text('kind');
            $table->text('unit')->nullable();
            $table->boolean('show_in_tasks')->default(true);
            $table->integer('sort')->default(0);
            $table->date('start_date');
            $table->time('preferred_time')->nullable();
            $table->timestampTz('paused_at')->nullable();
            $table->timestampTz('archived_at')->nullable();
            $table->uuid('converted_from_template_id')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'sort']);
        });
        DB::statement("ALTER TABLE habits.habits ADD CONSTRAINT habits_kind_check CHECK (kind IN ('check','quantity','avoid'))");

        Schema::create('habits.habit_goals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('habit_id')->constrained('habits.habits')->cascadeOnDelete();
            $table->date('valid_from');
            $table->text('period');
            $table->decimal('target', 12, 2);
            $table->timestampsTz();

            $table->unique(['habit_id', 'valid_from']);
        });
        DB::statement('ALTER TABLE habits.habit_goals ADD COLUMN days_of_week smallint[]');
        DB::statement("ALTER TABLE habits.habit_goals ADD CONSTRAINT habit_goals_period_check CHECK (period IN ('day','week'))");
        DB::statement('ALTER TABLE habits.habit_goals ADD CONSTRAINT habit_goals_target_check CHECK (target >= 0)');
        DB::statement("ALTER TABLE habits.habit_goals ADD CONSTRAINT habit_goals_days_check CHECK (days_of_week IS NULL OR (period = 'day' AND cardinality(days_of_week) BETWEEN 1 AND 7 AND days_of_week <@ ARRAY[1,2,3,4,5,6,7]::smallint[]))");

        Schema::create('habits.habit_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('habit_id')->constrained('habits.habits')->cascadeOnDelete();
            $table->date('date');
            $table->decimal('value', 12, 2);
            $table->text('note')->nullable();
            $table->text('source')->default('manual');
            $table->timestampsTz();

            $table->unique(['habit_id', 'date']);
        });
        DB::statement("ALTER TABLE habits.habit_entries ADD CONSTRAINT habit_entries_source_check CHECK (source IN ('manual','task_import','health'))");
        DB::statement('ALTER TABLE habits.habit_entries ADD CONSTRAINT habit_entries_value_check CHECK (value >= 0)');

        Schema::create('habits.habit_breaks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('habit_id')->nullable()->constrained('habits.habits')->cascadeOnDelete();
            $table->date('from_date');
            $table->date('to_date');
            $table->timestampsTz();

            $table->index(['user_id', 'from_date']);
        });
        DB::statement('ALTER TABLE habits.habit_breaks ADD CONSTRAINT habit_breaks_range_check CHECK (to_date >= from_date)');
    }

    public function down(): void
    {
        DB::statement('DROP SCHEMA IF EXISTS habits CASCADE');
    }
};
