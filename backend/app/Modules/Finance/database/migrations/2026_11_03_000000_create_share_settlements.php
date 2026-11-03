<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A share can now be paid back by several incomes (e.g. two Bizums) and one income can cover
 * several shares, so the single settlement_transaction_id column becomes a link table.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('finance.share_settlements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('share_id')->constrained('finance.shared_expense_shares')->cascadeOnDelete();
            $table->foreignUuid('transaction_id')->constrained('finance.transactions')->cascadeOnDelete();
            $table->bigInteger('amount_cents');
            $table->timestampsTz();

            $table->unique(['share_id', 'transaction_id']);
            $table->index('transaction_id');
        });
        DB::statement('ALTER TABLE finance.share_settlements ADD CONSTRAINT share_settlements_amount_check CHECK (amount_cents > 0)');

        DB::statement(<<<'SQL'
            INSERT INTO finance.share_settlements (id, share_id, transaction_id, amount_cents, created_at, updated_at)
            SELECT gen_random_uuid(), s.id, s.settlement_transaction_id, s.amount_cents, COALESCE(s.settled_at, now()), COALESCE(s.settled_at, now())
            FROM finance.shared_expense_shares s
            WHERE s.settlement_transaction_id IS NOT NULL
        SQL);

        Schema::table('finance.shared_expense_shares', function (Blueprint $table) {
            $table->dropColumn('settlement_transaction_id');
            $table->boolean('from_reimbursement')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('finance.shared_expense_shares', function (Blueprint $table) {
            $table->foreignUuid('settlement_transaction_id')->nullable()->constrained('finance.transactions')->nullOnDelete();
            $table->dropColumn('from_reimbursement');
        });

        DB::statement(<<<'SQL'
            UPDATE finance.shared_expense_shares s
            SET settlement_transaction_id = (SELECT ss.transaction_id FROM finance.share_settlements ss WHERE ss.share_id = s.id ORDER BY ss.created_at DESC LIMIT 1)
        SQL);

        Schema::drop('finance.share_settlements');
    }
};
