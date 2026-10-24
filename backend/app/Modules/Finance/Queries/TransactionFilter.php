<?php

namespace App\Modules\Finance\Queries;

use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

final readonly class TransactionFilter
{
    public const string NO_CATEGORY = 'none';

    public function __construct(private PeriodService $periods) {}

    /**
     * @param  array<string, mixed>  $filters
     * @return Builder<Transaction>
     */
    public function apply(string $userId, array $filters): Builder
    {
        $query = Transaction::query()->ownedBy($userId);

        if (isset($filters['period_id']) && is_string($filters['period_id'])) {
            $period = $this->periods->find($userId, $filters['period_id']);
            if ($period !== null) {
                $query->where('date', '>=', $period->start_date->toDateString());
                if ($period->end_date !== null) {
                    $query->where('date', '<=', $period->end_date->toDateString());
                }
            } else {
                $query->whereRaw('false');
            }
        }

        if (isset($filters['from'])) {
            $query->where('date', '>=', $filters['from']);
        }

        if (isset($filters['to'])) {
            $query->where('date', '<=', $filters['to']);
        }

        if (! empty($filters['account_id'])) {
            $query->whereIn('account_id', (array) $filters['account_id']);
        }

        if (! empty($filters['category_id'])) {
            $requested = (array) $filters['category_id'];
            $includeNone = in_array(self::NO_CATEGORY, $requested, true);
            $ids = array_values(array_filter($requested, fn ($id) => $id !== self::NO_CATEGORY));
            $expanded = $ids === [] ? [] : Category::query()->ownedBy($userId)
                ->where(fn (Builder $categories) => $categories->whereIn('id', $ids)->orWhereIn('parent_id', $ids))
                ->pluck('id')
                ->all();

            $query->where(function (Builder $categoryQuery) use ($expanded, $includeNone): void {
                if ($expanded !== []) {
                    $categoryQuery->whereIn('category_id', $expanded)
                        ->orWhereHas('splits', fn (Builder $splits) => $splits->whereIn('category_id', $expanded));
                }
                if ($includeNone) {
                    $categoryQuery->orWhere(fn (Builder $none) => $none
                        ->whereNull('category_id')
                        ->whereIn('kind', ['expense', 'income'])
                        ->whereDoesntHave('splits'));
                }
            });
        }

        if (! empty($filters['tag'])) {
            $tags = array_map(fn ($tag) => mb_strtolower(ltrim(trim((string) $tag), '#')), (array) $filters['tag']);
            $query->whereHas('tags', fn (Builder $tagQuery) => $tagQuery->whereIn('name', $tags));
        }

        if (! empty($filters['kind'])) {
            $query->whereIn('kind', (array) $filters['kind']);
        }

        if (isset($filters['min'])) {
            $query->whereRaw('abs(amount_cents) >= ?', [(int) $filters['min']]);
        }

        if (isset($filters['max'])) {
            $query->whereRaw('abs(amount_cents) <= ?', [(int) $filters['max']]);
        }

        if (isset($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (isset($filters['debt_id'])) {
            $query->where('debt_id', $filters['debt_id']);
        }

        if (isset($filters['recurring_rule_id'])) {
            $query->where('recurring_rule_id', $filters['recurring_rule_id']);
        }

        if (isset($filters['contact_id'])) {
            $query->whereHas('shares', fn (Builder $shares) => $shares->where('contact_id', $filters['contact_id']));
        }

        if (isset($filters['q']) && trim((string) $filters['q']) !== '') {
            $term = '%'.str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], trim((string) $filters['q'])).'%';
            $query->where(fn (Builder $search) => $search
                ->whereRaw("(coalesce(payee, '') || ' ' || coalesce(description, '')) ILIKE ?", [$term])
                ->orWhere('notes', 'ILIKE', $term));
        }

        return $query;
    }

    /**
     * @param  Builder<Transaction>  $query
     * @return array{count: int, income_cents: int, expense_cents: int, own_expense_cents: int, net_cents: int}
     */
    public function totals(Builder $query): array
    {
        $base = $query->clone()->reorder()->toBase();
        $base->columns = null;

        $row = DB::query()->fromSub(
            $base->select(['id', 'kind', 'amount_cents']),
            'filtered',
        )->selectRaw(<<<'SQL'
            count(*) AS count,
            coalesce(sum(CASE WHEN kind = 'income' THEN amount_cents ELSE 0 END), 0)::bigint AS income_cents,
            coalesce(sum(CASE WHEN kind = 'expense' THEN amount_cents ELSE 0 END), 0)::bigint AS expense_cents,
            coalesce(sum(CASE WHEN kind = 'expense' THEN amount_cents + coalesce((SELECT sum(s.amount_cents) FROM finance.shared_expense_shares s WHERE s.transaction_id = filtered.id), 0) ELSE 0 END), 0)::bigint AS own_expense_cents
        SQL)->first();

        $income = (int) ($row->income_cents ?? 0);
        $expense = (int) ($row->expense_cents ?? 0);

        return [
            'count' => (int) ($row->count ?? 0),
            'income_cents' => $income,
            'expense_cents' => $expense,
            'own_expense_cents' => (int) ($row->own_expense_cents ?? 0),
            'net_cents' => $income + $expense,
        ];
    }
}
