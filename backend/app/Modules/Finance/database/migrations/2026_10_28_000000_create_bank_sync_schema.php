<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('finance.bank_connections', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('provider')->default('enable_banking');
            $table->text('aspsp_name');
            $table->char('aspsp_country', 2);
            $table->text('session_id')->nullable();
            $table->timestampTz('valid_until');
            $table->text('status')->default('active');
            $table->jsonb('accounts')->nullable();
            $table->smallInteger('expiry_notice_days')->nullable();
            $table->timestampTz('last_synced_at')->nullable();
            $table->text('last_error')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'status']);
            $table->index(['status', 'valid_until']);
        });
        DB::statement("ALTER TABLE finance.bank_connections ADD CONSTRAINT bank_connections_status_check CHECK (status IN ('active','expired','revoked','error'))");

        Schema::table('finance.accounts', function (Blueprint $table) {
            $table->foreignUuid('bank_connection_id')->nullable()->constrained('finance.bank_connections')->nullOnDelete();
            $table->text('external_account_uid')->nullable();
            $table->text('external_account_hash')->nullable();
            $table->date('sync_from_date')->nullable();
            $table->bigInteger('bank_balance_cents')->nullable();
            $table->timestampTz('bank_balance_at')->nullable();

            $table->unique(['bank_connection_id', 'external_account_uid']);
        });

        Schema::table('finance.transactions', function (Blueprint $table) {
            $table->text('external_id')->nullable();
            $table->jsonb('raw')->nullable();

            $table->unique(['account_id', 'external_id']);
        });

        Schema::create('finance.category_rules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('pattern');
            $table->text('kind');
            $table->foreignUuid('category_id')->constrained('finance.categories')->cascadeOnDelete();
            $table->timestampsTz();

            $table->unique(['user_id', 'kind', 'pattern']);
        });
        DB::statement("ALTER TABLE finance.category_rules ADD CONSTRAINT category_rules_kind_check CHECK (kind IN ('expense','income'))");
        DB::statement('ALTER TABLE finance.category_rules ADD CONSTRAINT category_rules_pattern_check CHECK (length(pattern) >= 2)');
    }

    public function down(): void
    {
        Schema::dropIfExists('finance.category_rules');

        Schema::table('finance.transactions', function (Blueprint $table) {
            $table->dropUnique(['account_id', 'external_id']);
            $table->dropColumn(['external_id', 'raw']);
        });

        Schema::table('finance.accounts', function (Blueprint $table) {
            $table->dropUnique(['bank_connection_id', 'external_account_uid']);
            $table->dropConstrainedForeignId('bank_connection_id');
            $table->dropColumn(['external_account_uid', 'external_account_hash', 'sync_from_date', 'bank_balance_cents', 'bank_balance_at']);
        });

        Schema::dropIfExists('finance.bank_connections');
    }
};
