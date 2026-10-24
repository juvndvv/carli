<?php

namespace App\Modules\Finance\Queries;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class SpendingQuery
{
    public const string UNCATEGORIZED = 'uncategorized';

    /**
     * @return array<string, int>
     */
    public function ownSpendingByCategory(string $userId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $rows = DB::select(<<<'SQL'
            WITH expenses AS (
                SELECT t.id, t.category_id, -t.amount_cents AS gross,
                    COALESCE((SELECT SUM(s.amount_cents) FROM finance.shared_expense_shares s WHERE s.transaction_id = t.id), 0) AS shared
                FROM finance.transactions t
                WHERE t.user_id = ? AND t.deleted_at IS NULL AND t.kind = 'expense' AND t.date BETWEEN ? AND ?
            ),
            lines AS (
                SELECT COALESCE(sp.category_id, e.category_id) AS category_id,
                    CASE WHEN sp.id IS NULL THEN e.gross - e.shared
                        ELSE ROUND((-sp.amount_cents)::numeric * (e.gross - e.shared) / NULLIF(e.gross, 0))
                    END AS own
                FROM expenses e
                LEFT JOIN finance.transaction_splits sp ON sp.transaction_id = e.id
            )
            SELECT category_id, COALESCE(SUM(own), 0)::bigint AS own_cents
            FROM lines
            GROUP BY category_id
        SQL, [$userId, $from->toDateString(), $to->toDateString()]);

        $result = [];
        foreach ($rows as $row) {
            $result[$row->category_id ?? self::UNCATEGORIZED] = (int) $row->own_cents;
        }

        return $result;
    }

    public function ownSpendingTotal(string $userId, CarbonImmutable $from, CarbonImmutable $to): int
    {
        return array_sum($this->ownSpendingByCategory($userId, $from, $to));
    }

    public function incomeTotal(string $userId, CarbonImmutable $from, CarbonImmutable $to): int
    {
        return (int) DB::table('finance.transactions as t')
            ->where('t.user_id', $userId)
            ->whereNull('t.deleted_at')
            ->where('t.kind', 'income')
            ->whereBetween('t.date', [$from->toDateString(), $to->toDateString()])
            ->whereNotExists(fn ($query) => $query->from('finance.shared_expense_shares as s')->whereColumn('s.settlement_transaction_id', 't.id'))
            ->sum('t.amount_cents');
    }

    /**
     * @param  array<string, int>  $byCategory
     * @param  array<string, string|null>  $parentOf
     * @return array<string, int>
     */
    public static function rollUp(array $byCategory, array $parentOf): array
    {
        $rolled = [];
        foreach ($byCategory as $categoryId => $cents) {
            $topLevel = $parentOf[$categoryId] ?? null;
            $key = $topLevel ?? $categoryId;
            $rolled[$key] = ($rolled[$key] ?? 0) + $cents;
        }

        return $rolled;
    }
}
