<?php

namespace App\Modules\Finance\Queries;

use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

final class FinanceBackup
{
    public const string FORMAT = 'personal-app/finance-backup';

    public const int VERSION = 1;

    private const array OWNED_TABLES = [
        'settings', 'accounts', 'categories', 'tags', 'contacts', 'recurring_rules', 'debts',
        'transactions', 'periods', 'budgets', 'savings_goals',
    ];

    private const array TRANSACTION_CHILD_TABLES = ['transaction_splits', 'transaction_tag', 'shared_expense_shares'];

    /**
     * @return array{format: string, version: int, exported_at: string, tables: array<string, list<array<string, mixed>>>}
     */
    public function export(string $userId): array
    {
        $tables = [];

        foreach (self::OWNED_TABLES as $table) {
            $tables[$table] = $this->rows(DB::table("finance.{$table}")->where('user_id', $userId), 'id');
        }

        $transactionIds = DB::table('finance.transactions')->where('user_id', $userId)->select('id');
        foreach (self::TRANSACTION_CHILD_TABLES as $table) {
            $tables[$table] = $this->rows(
                DB::table("finance.{$table}")->whereIn('transaction_id', $transactionIds),
                $table === 'transaction_tag' ? null : 'id',
            );
        }

        $tables['goal_contributions'] = $this->rows(
            DB::table('finance.goal_contributions')->whereIn('goal_id', DB::table('finance.savings_goals')->where('user_id', $userId)->select('id')),
            'id',
        );

        return [
            'format' => self::FORMAT,
            'version' => self::VERSION,
            'exported_at' => CarbonImmutable::now()->toIso8601String(),
            'tables' => $tables,
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function rows(Builder $query, ?string $orderColumn): array
    {
        $query = $orderColumn === null ? $query->orderBy('transaction_id')->orderBy('tag_id') : $query->orderBy($orderColumn);

        return array_values(array_map(fn (object $row) => (array) $row, $query->get()->all()));
    }
}
