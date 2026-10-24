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
        DB::statement('CREATE EXTENSION IF NOT EXISTS btree_gist');
        DB::statement('CREATE SCHEMA IF NOT EXISTS finance');

        Schema::create('finance.accounts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->text('type');
            $table->bigInteger('initial_balance_cents')->default(0);
            $table->date('initial_balance_date')->nullable();
            $table->bigInteger('credit_limit_cents')->nullable();
            $table->smallInteger('statement_day')->nullable();
            $table->smallInteger('payment_day')->nullable();
            $table->text('color')->nullable();
            $table->text('icon')->nullable();
            $table->boolean('include_in_net_worth')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'sort_order']);
        });
        DB::statement("ALTER TABLE finance.accounts ADD CONSTRAINT accounts_type_check CHECK (type IN ('checking','savings','credit_card','cash'))");
        DB::statement('ALTER TABLE finance.accounts ADD CONSTRAINT accounts_statement_day_check CHECK (statement_day IS NULL OR statement_day BETWEEN 1 AND 31)');
        DB::statement('ALTER TABLE finance.accounts ADD CONSTRAINT accounts_payment_day_check CHECK (payment_day IS NULL OR payment_day BETWEEN 1 AND 31)');
        DB::statement('ALTER TABLE finance.accounts ADD CONSTRAINT accounts_credit_limit_check CHECK (credit_limit_cents IS NULL OR credit_limit_cents >= 0)');

        Schema::create('finance.categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('parent_id')->nullable();
            $table->text('name');
            $table->text('kind');
            $table->text('icon')->nullable();
            $table->text('color')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('opens_period')->default(false);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'kind']);
        });
        Schema::table('finance.categories', function (Blueprint $table) {
            $table->foreign('parent_id')->references('id')->on('finance.categories')->restrictOnDelete();
        });
        DB::statement("ALTER TABLE finance.categories ADD CONSTRAINT categories_kind_check CHECK (kind IN ('expense','income'))");
        DB::statement("ALTER TABLE finance.categories ADD CONSTRAINT categories_opens_period_check CHECK (NOT opens_period OR kind = 'income')");
        DB::statement('ALTER TABLE finance.categories ADD CONSTRAINT categories_user_parent_name_unique UNIQUE NULLS NOT DISTINCT (user_id, parent_id, name)');

        Schema::create('finance.tags', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->text('color')->nullable();
            $table->timestampsTz();

            $table->unique(['user_id', 'name']);
        });

        Schema::create('finance.contacts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->text('notes')->nullable();
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'name']);
        });

        Schema::create('finance.recurring_rules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('account_id')->constrained('finance.accounts')->restrictOnDelete();
            $table->foreignUuid('category_id')->nullable()->constrained('finance.categories')->nullOnDelete();
            $table->text('kind');
            $table->bigInteger('amount_cents');
            $table->text('payee')->nullable();
            $table->text('description')->nullable();
            $table->text('frequency');
            $table->smallInteger('interval')->default(1);
            $table->smallInteger('day_of_month')->nullable();
            $table->date('start_date');
            $table->date('end_date')->nullable();
            $table->date('next_occurrence')->nullable();
            $table->text('mode')->default('auto');
            $table->smallInteger('remind_days_before')->default(2);
            $table->boolean('is_subscription')->default(false);
            $table->timestampTz('cancelled_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'next_occurrence']);
        });
        DB::statement("ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_kind_check CHECK (kind IN ('expense','income'))");
        DB::statement("ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_frequency_check CHECK (frequency IN ('daily','weekly','monthly','yearly'))");
        DB::statement("ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_mode_check CHECK (mode IN ('auto','confirm'))");
        DB::statement('ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_interval_check CHECK (interval >= 1)');
        DB::statement('ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_day_of_month_check CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31)');
        DB::statement('ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_amount_check CHECK (amount_cents <> 0)');
        DB::statement('ALTER TABLE finance.recurring_rules ADD CONSTRAINT recurring_rules_remind_check CHECK (remind_days_before >= 0)');

        Schema::create('finance.debts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('contact_id')->nullable()->constrained('finance.contacts')->nullOnDelete();
            $table->text('name');
            $table->text('direction');
            $table->bigInteger('principal_cents');
            $table->date('start_date');
            $table->date('due_date')->nullable();
            $table->bigInteger('installment_cents')->nullable();
            $table->integer('installments_count')->nullable();
            $table->foreignUuid('recurring_rule_id')->nullable()->constrained('finance.recurring_rules')->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestampTz('closed_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'closed_at']);
        });
        DB::statement("ALTER TABLE finance.debts ADD CONSTRAINT debts_direction_check CHECK (direction IN ('i_owe','owed_to_me'))");
        DB::statement('ALTER TABLE finance.debts ADD CONSTRAINT debts_principal_check CHECK (principal_cents > 0)');
        DB::statement('ALTER TABLE finance.debts ADD CONSTRAINT debts_installment_check CHECK (installment_cents IS NULL OR installment_cents > 0)');
        DB::statement('ALTER TABLE finance.debts ADD CONSTRAINT debts_installments_count_check CHECK (installments_count IS NULL OR installments_count > 0)');

        Schema::create('finance.transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('account_id')->constrained('finance.accounts')->restrictOnDelete();
            $table->text('kind');
            $table->bigInteger('amount_cents');
            $table->date('date');
            $table->foreignUuid('category_id')->nullable()->constrained('finance.categories')->restrictOnDelete();
            $table->text('payee')->nullable();
            $table->text('description')->nullable();
            $table->text('notes')->nullable();
            $table->text('status')->default('cleared');
            $table->uuid('transfer_group_id')->nullable();
            $table->foreignUuid('recurring_rule_id')->nullable()->constrained('finance.recurring_rules')->nullOnDelete();
            $table->date('recurring_date')->nullable();
            $table->foreignUuid('debt_id')->nullable()->constrained('finance.debts')->nullOnDelete();
            $table->timestampTz('deleted_at')->nullable();
            $table->timestampsTz();

            $table->index(['account_id', 'date']);
            $table->index(['category_id', 'date']);
            $table->index('transfer_group_id');
            $table->index('debt_id');
            $table->unique(['recurring_rule_id', 'recurring_date']);
        });
        DB::statement('CREATE INDEX transactions_user_date_index ON finance.transactions (user_id, date DESC, id DESC)');
        DB::statement("CREATE INDEX transactions_search_trgm_index ON finance.transactions USING gin ((coalesce(payee, '') || ' ' || coalesce(description, '')) gin_trgm_ops)");
        DB::statement("ALTER TABLE finance.transactions ADD CONSTRAINT transactions_kind_check CHECK (kind IN ('expense','income','transfer','adjustment'))");
        DB::statement("ALTER TABLE finance.transactions ADD CONSTRAINT transactions_status_check CHECK (status IN ('pending','cleared'))");
        DB::statement('ALTER TABLE finance.transactions ADD CONSTRAINT transactions_amount_check CHECK (amount_cents <> 0)');
        DB::statement("ALTER TABLE finance.transactions ADD CONSTRAINT transactions_transfer_group_check CHECK ((kind = 'transfer') = (transfer_group_id IS NOT NULL))");
        DB::statement("ALTER TABLE finance.transactions ADD CONSTRAINT transactions_transfer_category_check CHECK (kind <> 'transfer' OR category_id IS NULL)");

        Schema::create('finance.transaction_splits', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('transaction_id')->constrained('finance.transactions')->cascadeOnDelete();
            $table->foreignUuid('category_id')->constrained('finance.categories')->restrictOnDelete();
            $table->bigInteger('amount_cents');
            $table->timestampsTz();

            $table->index('category_id');
        });

        Schema::create('finance.transaction_tag', function (Blueprint $table) {
            $table->foreignUuid('transaction_id')->constrained('finance.transactions')->cascadeOnDelete();
            $table->foreignUuid('tag_id')->constrained('finance.tags')->cascadeOnDelete();

            $table->primary(['transaction_id', 'tag_id']);
            $table->index('tag_id');
        });

        Schema::create('finance.periods', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->date('start_date');
            $table->date('end_date')->nullable();
            $table->date('expected_end_date')->nullable();
            $table->text('opened_by');
            $table->foreignUuid('opening_transaction_id')->nullable()->constrained('finance.transactions')->nullOnDelete();
            $table->timestampTz('payroll_overdue_notified_at')->nullable();
            $table->timestampsTz();
        });
        DB::statement("ALTER TABLE finance.periods ADD CONSTRAINT periods_opened_by_check CHECK (opened_by IN ('payroll','manual','calendar'))");
        DB::statement('ALTER TABLE finance.periods ADD CONSTRAINT periods_range_check CHECK (end_date IS NULL OR end_date >= start_date)');
        DB::statement('ALTER TABLE finance.periods ADD CONSTRAINT periods_user_start_unique UNIQUE (user_id, start_date) DEFERRABLE INITIALLY IMMEDIATE');
        DB::statement("ALTER TABLE finance.periods ADD CONSTRAINT periods_no_overlap EXCLUDE USING gist (user_id WITH =, daterange(start_date, end_date, '[]') WITH &&) DEFERRABLE INITIALLY IMMEDIATE");

        Schema::create('finance.budgets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('category_id')->constrained('finance.categories')->cascadeOnDelete();
            $table->foreignUuid('period_id')->constrained('finance.periods')->cascadeOnDelete();
            $table->bigInteger('amount_cents');
            $table->boolean('rollover')->default(false);
            $table->smallInteger('notified_threshold')->nullable();
            $table->timestampsTz();

            $table->unique(['user_id', 'category_id', 'period_id']);
            $table->index('period_id');
        });
        DB::statement('ALTER TABLE finance.budgets ADD CONSTRAINT budgets_amount_check CHECK (amount_cents >= 0)');

        Schema::create('finance.savings_goals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->bigInteger('target_cents');
            $table->date('target_date')->nullable();
            $table->foreignUuid('account_id')->nullable()->constrained('finance.accounts')->nullOnDelete();
            $table->text('icon')->nullable();
            $table->text('color')->nullable();
            $table->smallInteger('notified_milestone')->default(0);
            $table->timestampTz('achieved_at')->nullable();
            $table->timestampsTz();

            $table->index('user_id');
        });
        DB::statement('ALTER TABLE finance.savings_goals ADD CONSTRAINT savings_goals_target_check CHECK (target_cents > 0)');

        Schema::create('finance.goal_contributions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('goal_id')->constrained('finance.savings_goals')->cascadeOnDelete();
            $table->bigInteger('amount_cents');
            $table->date('date');
            $table->foreignUuid('transaction_id')->nullable()->constrained('finance.transactions')->nullOnDelete();
            $table->text('note')->nullable();
            $table->timestampsTz();

            $table->index(['goal_id', 'date']);
        });
        DB::statement('ALTER TABLE finance.goal_contributions ADD CONSTRAINT goal_contributions_amount_check CHECK (amount_cents <> 0)');

        Schema::create('finance.shared_expense_shares', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('transaction_id')->constrained('finance.transactions')->cascadeOnDelete();
            $table->foreignUuid('contact_id')->constrained('finance.contacts')->restrictOnDelete();
            $table->bigInteger('amount_cents');
            $table->timestampTz('settled_at')->nullable();
            $table->foreignUuid('settlement_transaction_id')->nullable()->constrained('finance.transactions')->nullOnDelete();
            $table->timestampsTz();

            $table->index('transaction_id');
            $table->index(['contact_id', 'settled_at']);
            $table->index('settlement_transaction_id');
        });
        DB::statement('ALTER TABLE finance.shared_expense_shares ADD CONSTRAINT shared_expense_shares_amount_check CHECK (amount_cents > 0)');

        Schema::create('finance.settings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('default_account_id')->nullable()->constrained('finance.accounts')->nullOnDelete();
            $table->smallInteger('budget_warning_threshold')->default(80);
            $table->smallInteger('period_min_days')->default(20);
            $table->text('period_mode')->default('payroll');
            $table->smallInteger('remind_days_before')->default(2);
            $table->timestampsTz();
        });
        DB::statement("ALTER TABLE finance.settings ADD CONSTRAINT settings_period_mode_check CHECK (period_mode IN ('payroll','calendar'))");
        DB::statement('ALTER TABLE finance.settings ADD CONSTRAINT settings_warning_threshold_check CHECK (budget_warning_threshold BETWEEN 1 AND 100)');
        DB::statement('ALTER TABLE finance.settings ADD CONSTRAINT settings_period_min_days_check CHECK (period_min_days BETWEEN 1 AND 60)');
        DB::statement('ALTER TABLE finance.settings ADD CONSTRAINT settings_remind_days_check CHECK (remind_days_before BETWEEN 0 AND 30)');
    }

    public function down(): void
    {
        DB::statement('DROP SCHEMA IF EXISTS finance CASCADE');
    }
};
