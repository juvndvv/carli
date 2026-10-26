<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE EXTENSION IF NOT EXISTS pg_trgm');
        DB::statement('CREATE SCHEMA IF NOT EXISTS tasks');

        Schema::create('tasks.task_lists', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->text('color')->nullable();
            $table->text('icon')->nullable();
            $table->boolean('is_default')->default(false);
            $table->integer('sort_order')->default(0);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'sort_order']);
        });
        DB::statement('CREATE UNIQUE INDEX task_lists_one_default_per_user ON tasks.task_lists (user_id) WHERE is_default');

        Schema::create('tasks.task_templates', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('list_id')->constrained('tasks.task_lists')->restrictOnDelete();
            $table->text('title');
            $table->text('notes')->nullable();
            $table->jsonb('subtasks')->default('[]');
            $table->text('rrule')->nullable();
            $table->date('dtstart');
            $table->date('until')->nullable();
            $table->integer('count')->nullable();
            $table->integer('after_done_interval_days')->nullable();
            $table->text('policy')->default('replace');
            $table->smallInteger('lead_days')->default(0);
            $table->time('due_time')->nullable();
            $table->boolean('important')->default(false);
            $table->date('generated_through')->nullable();
            $table->date('next_due_date')->nullable();
            $table->timestampTz('paused_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'paused_at']);
        });
        DB::statement("ALTER TABLE tasks.task_templates ADD CONSTRAINT task_templates_policy_check CHECK (policy IN ('replace','accumulate'))");
        DB::statement('ALTER TABLE tasks.task_templates ADD CONSTRAINT task_templates_frequency_check CHECK ((rrule IS NULL) <> (after_done_interval_days IS NULL))');
        DB::statement('ALTER TABLE tasks.task_templates ADD CONSTRAINT task_templates_after_done_check CHECK (after_done_interval_days IS NULL OR after_done_interval_days BETWEEN 1 AND 3650)');
        DB::statement('ALTER TABLE tasks.task_templates ADD CONSTRAINT task_templates_lead_days_check CHECK (lead_days BETWEEN 0 AND 365)');
        DB::statement('ALTER TABLE tasks.task_templates ADD CONSTRAINT task_templates_count_check CHECK (count IS NULL OR count > 0)');
        DB::statement('ALTER TABLE tasks.task_templates ADD CONSTRAINT task_templates_ending_check CHECK (until IS NULL OR count IS NULL)');

        Schema::create('tasks.tasks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('list_id')->constrained('tasks.task_lists')->restrictOnDelete();
            $table->foreignUuid('template_id')->nullable()->constrained('tasks.task_templates')->nullOnDelete();
            $table->date('occurrence_date')->nullable();
            $table->text('title');
            $table->text('notes')->nullable();
            $table->date('due_date')->nullable();
            $table->time('due_time')->nullable();
            $table->text('status')->default('open');
            $table->text('skip_reason')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('skipped_at')->nullable();
            $table->boolean('important')->default(false);
            $table->integer('sort')->default(0);
            $table->timestampsTz();

            $table->unique(['template_id', 'occurrence_date']);
            $table->index(['user_id', 'list_id', 'status']);
            $table->index(['user_id', 'completed_at']);
        });
        DB::statement("ALTER TABLE tasks.tasks ADD CONSTRAINT tasks_status_check CHECK (status IN ('open','done','skipped'))");
        DB::statement("ALTER TABLE tasks.tasks ADD CONSTRAINT tasks_skip_reason_check CHECK (skip_reason IS NULL OR skip_reason IN ('manual','replaced','missed'))");
        DB::statement('ALTER TABLE tasks.tasks ADD CONSTRAINT tasks_occurrence_check CHECK ((template_id IS NULL) OR (occurrence_date IS NOT NULL))');
        DB::statement("CREATE INDEX tasks_open_by_due_date ON tasks.tasks (user_id, due_date) WHERE status = 'open'");
        DB::statement('CREATE INDEX tasks_title_trgm ON tasks.tasks USING gin (title gin_trgm_ops)');

        Schema::create('tasks.task_subtasks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('task_id')->constrained('tasks.tasks')->cascadeOnDelete();
            $table->text('title');
            $table->timestampTz('done_at')->nullable();
            $table->integer('sort')->default(0);
            $table->timestampsTz();

            $table->index(['task_id', 'sort']);
        });

        Schema::create('tasks.task_template_exceptions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('template_id')->constrained('tasks.task_templates')->cascadeOnDelete();
            $table->date('date');
            $table->timestampTz('created_at')->nullable();

            $table->unique(['template_id', 'date']);
        });
    }

    public function down(): void
    {
        DB::statement('DROP SCHEMA IF EXISTS tasks CASCADE');
    }
};
