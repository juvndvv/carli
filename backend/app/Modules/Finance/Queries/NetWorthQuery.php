<?php

namespace App\Modules\Finance\Queries;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

final class NetWorthQuery
{
    public function current(string $userId): int
    {
        $row = DB::selectOne(<<<'SQL'
            SELECT COALESCE(SUM(a.initial_balance_cents), 0)::bigint
                + COALESCE((SELECT SUM(t.amount_cents) FROM finance.transactions t
                    JOIN finance.accounts ta ON ta.id = t.account_id
                    WHERE t.user_id = ? AND t.deleted_at IS NULL AND ta.include_in_net_worth AND ta.archived_at IS NULL), 0)::bigint AS total
            FROM finance.accounts a
            WHERE a.user_id = ? AND a.include_in_net_worth AND a.archived_at IS NULL
        SQL, [$userId, $userId]);

        return (int) ($row->total ?? 0);
    }

    public function at(string $userId, CarbonImmutable $date): int
    {
        $row = DB::selectOne(<<<'SQL'
            SELECT COALESCE(SUM(a.initial_balance_cents), 0)::bigint
                + COALESCE((SELECT SUM(t.amount_cents) FROM finance.transactions t
                    JOIN finance.accounts ta ON ta.id = t.account_id
                    WHERE t.user_id = ? AND t.deleted_at IS NULL AND t.date <= ? AND ta.include_in_net_worth AND ta.archived_at IS NULL), 0)::bigint AS total
            FROM finance.accounts a
            WHERE a.user_id = ? AND a.include_in_net_worth AND a.archived_at IS NULL
                AND (a.initial_balance_date IS NULL OR a.initial_balance_date <= ?)
        SQL, [$userId, $date->toDateString(), $userId, $date->toDateString()]);

        return (int) ($row->total ?? 0);
    }
}
