<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('finance.transactions', function (Blueprint $table) {
            $table->text('transfer_source')->nullable();
            $table->timestampTz('transfer_detected_at')->nullable();
        });
        DB::statement("ALTER TABLE finance.transactions ADD CONSTRAINT transactions_transfer_source_check CHECK (transfer_source IN ('auto','confirmed','linked'))");
        DB::statement("CREATE INDEX transactions_transfer_candidates_index ON finance.transactions (user_id, amount_cents, date) WHERE source = 'bank' AND kind IN ('expense','income') AND deleted_at IS NULL");

        Schema::create('finance.transfer_exclusions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('outgoing_transaction_id')->constrained('finance.transactions')->cascadeOnDelete();
            $table->foreignUuid('incoming_transaction_id')->constrained('finance.transactions')->cascadeOnDelete();
            $table->timestampsTz();

            $table->unique(['outgoing_transaction_id', 'incoming_transaction_id']);
            $table->index('incoming_transaction_id');
        });

        Schema::table('finance.bank_connections', function (Blueprint $table) {
            $table->integer('last_sync_transfers')->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('finance.bank_connections', function (Blueprint $table) {
            $table->dropColumn('last_sync_transfers');
        });

        Schema::dropIfExists('finance.transfer_exclusions');

        DB::statement('DROP INDEX IF EXISTS finance.transactions_transfer_candidates_index');
        Schema::table('finance.transactions', function (Blueprint $table) {
            $table->dropColumn(['transfer_source', 'transfer_detected_at']);
        });
    }
};
