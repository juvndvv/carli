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
            $table->text('source')->default('manual');
        });
        DB::statement("ALTER TABLE finance.transactions ADD CONSTRAINT transactions_source_check CHECK (source IN ('manual','recurring','bank'))");
        DB::statement("UPDATE finance.transactions SET source = 'recurring' WHERE recurring_rule_id IS NOT NULL");
        DB::statement("CREATE INDEX transactions_uncategorized_index ON finance.transactions (user_id, date DESC, id DESC) WHERE category_id IS NULL AND kind IN ('expense','income') AND deleted_at IS NULL");
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS finance.transactions_uncategorized_index');
        Schema::table('finance.transactions', function (Blueprint $table) {
            $table->dropColumn('source');
        });
    }
};
