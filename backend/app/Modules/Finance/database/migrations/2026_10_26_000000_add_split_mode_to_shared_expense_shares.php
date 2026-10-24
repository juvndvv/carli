<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('finance.shared_expense_shares', function (Blueprint $table) {
            $table->text('mode')->default('amount');
            $table->integer('basis_points')->nullable();
            $table->boolean('include_self')->default(true);
        });
        DB::statement("ALTER TABLE finance.shared_expense_shares ADD CONSTRAINT shared_expense_shares_mode_check CHECK (mode IN ('equal','percentage','amount'))");
        DB::statement('ALTER TABLE finance.shared_expense_shares ADD CONSTRAINT shared_expense_shares_basis_points_check CHECK (basis_points IS NULL OR basis_points BETWEEN 1 AND 10000)');
    }

    public function down(): void
    {
        Schema::table('finance.shared_expense_shares', function (Blueprint $table) {
            $table->dropColumn(['mode', 'basis_points', 'include_self']);
        });
    }
};
