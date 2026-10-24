<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\BudgetStatus;
use App\Modules\Finance\Domain\Enums\CategoryKind;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Support\PeriodPresenter;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Notifications\BudgetThresholdReached;
use App\Modules\Finance\Queries\SpendingQuery;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class BudgetService
{
    private const int MAX_ROLLOVER_DEPTH = 12;

    /** @var array<string, array<string, int>> */
    private array $spendingCache = [];

    public function __construct(
        private readonly SpendingQuery $spending,
        private readonly PeriodService $periods,
        private readonly FinanceSettingsService $settings,
    ) {}

    /**
     * @return list<array<string, mixed>>
     */
    public function overview(Period $period): array
    {
        $this->spendingCache = [];
        $budgets = Budget::query()->ownedBy($period->user_id)->where('period_id', $period->id)->with('category.parent')->get();

        $rows = $budgets->map(fn (Budget $budget) => $this->row($budget, $period))->values()->all();

        usort($rows, fn (array $left, array $right) => [$left['category']['sort_key'], $left['category']['name']] <=> [$right['category']['sort_key'], $right['category']['name']]);

        return $rows;
    }

    /**
     * @param  list<array<string, mixed>>  $rows
     * @return array{budgeted_cents: int, spent_cents: int, remaining_cents: int, percent_bp: int|null, projected_cents: int}
     */
    public function totals(array $rows): array
    {
        $budgeted = array_sum(array_map(fn (array $row) => (int) $row['available_cents'], $rows));
        $spent = array_sum(array_map(fn (array $row) => (int) $row['spent_cents'], $rows));
        $projected = array_sum(array_map(fn (array $row) => (int) $row['projected_cents'], $rows));

        return [
            'budgeted_cents' => $budgeted,
            'spent_cents' => $spent,
            'remaining_cents' => $budgeted - $spent,
            'percent_bp' => Money::ofCents($spent)->ratioBasisPoints($budgeted),
            'projected_cents' => $projected,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function row(Budget $budget, Period $period): array
    {
        $category = $budget->category;
        $spent = $this->spentFor($period, $category);
        $rolloverIn = $budget->rollover ? $this->rolloverInto($budget, $period, 0) : 0;
        $available = $budget->amount_cents + $rolloverIn;
        $percent = Money::ofCents($spent)->ratioBasisPoints($available);
        $projected = $this->projection($period, $spent);
        $warning = $this->settings->for($period->user_id)->budget_warning_threshold * 100;

        return [
            'id' => $budget->id,
            'period_id' => $budget->period_id,
            'category_id' => $budget->category_id,
            'category' => [
                'id' => $category->id,
                'name' => $category->name,
                'parent' => $category->parent?->name,
                'parent_id' => $category->parent_id,
                'icon' => $category->icon,
                'color' => $category->color ?? $category->parent?->color,
                'sort_key' => ($category->parent->sort_order ?? $category->sort_order) * 1000 + ($category->parent_id === null ? 0 : $category->sort_order + 1),
            ],
            'amount_cents' => $budget->amount_cents,
            'rollover' => $budget->rollover,
            'rollover_in_cents' => $rolloverIn,
            'available_cents' => $available,
            'spent_cents' => $spent,
            'remaining_cents' => $available - $spent,
            'percent_bp' => $percent,
            'status' => self::status($spent, $available, $warning)->value,
            'projected_cents' => $projected,
            'projected_status' => self::status($projected, $available, $warning)->value,
        ];
    }

    public static function status(int $spent, int $available, int $warningBasisPoints): BudgetStatus
    {
        if ($available <= 0) {
            return $spent > 0 ? BudgetStatus::Exceeded : BudgetStatus::Ok;
        }

        $percent = Money::ofCents($spent)->ratioBasisPoints($available) ?? 0;

        return match (true) {
            $percent > 10_000 => BudgetStatus::Exceeded,
            $percent >= $warningBasisPoints => BudgetStatus::Warning,
            default => BudgetStatus::Ok,
        };
    }

    public function spentFor(Period $period, Category $category): int
    {
        $spending = $this->spendingFor($period);
        $total = $spending[$category->id] ?? 0;

        if ($category->parent_id === null) {
            foreach ($category->selfAndChildIds() as $childId) {
                if ($childId !== $category->id) {
                    $total += $spending[$childId] ?? 0;
                }
            }
        }

        return $total;
    }

    public function projection(Period $period, int $spent): int
    {
        if (! $period->isOpen()) {
            return $spent;
        }

        $elapsed = PeriodPresenter::elapsedDays($period);
        if ($elapsed <= 0) {
            return $spent;
        }

        return Money::ofCents($spent)->multiply(PeriodPresenter::totalDays($period), $elapsed)->cents;
    }

    /**
     * @param  list<array{category_id: string, amount_cents: int|null, rollover?: bool|null}>  $items
     */
    public function upsert(Period $period, array $items): void
    {
        DB::transaction(function () use ($period, $items): void {
            foreach ($items as $item) {
                $category = Category::query()->ownedBy($period->user_id)->whereKey($item['category_id'])->first();

                if ($category === null || $category->kind !== CategoryKind::Expense) {
                    throw ValidationException::withMessages(['budgets' => 'Solo se pueden presupuestar categorías de gasto.']);
                }

                $budget = Budget::query()->ownedBy($period->user_id)
                    ->where('period_id', $period->id)
                    ->where('category_id', $category->id)
                    ->first();

                if ($item['amount_cents'] === null) {
                    $budget?->delete();

                    continue;
                }

                if ($budget === null) {
                    $budget = new Budget(['period_id' => $period->id, 'category_id' => $category->id]);
                    $budget->user_id = $period->user_id;
                }

                if ($budget->exists && $budget->amount_cents !== $item['amount_cents']) {
                    $budget->notified_threshold = null;
                }

                $budget->amount_cents = $item['amount_cents'];
                if (array_key_exists('rollover', $item) && $item['rollover'] !== null) {
                    $budget->rollover = $item['rollover'];
                }
                $budget->save();
            }
        });
    }

    public function copy(Period $from, Period $to): int
    {
        if ($from->is($to)) {
            throw ValidationException::withMessages(['to_period_id' => 'El periodo de destino debe ser distinto.']);
        }

        return DB::transaction(fn () => $this->periods->copyBudgets($from, $to));
    }

    public function checkThresholds(Transaction $transaction): void
    {
        if ($transaction->kind !== TransactionKind::Expense) {
            return;
        }

        $period = $this->periods->forDate($transaction->user_id, $transaction->date);
        if ($period === null) {
            return;
        }

        $categoryIds = array_filter(array_merge([$transaction->category_id], $transaction->splits()->pluck('category_id')->all()));
        if ($categoryIds === []) {
            return;
        }

        $parentIds = Category::query()->ownedBy($transaction->user_id)->whereIn('id', $categoryIds)->whereNotNull('parent_id')->pluck('parent_id')->all();
        $warning = $this->settings->for($transaction->user_id)->budget_warning_threshold;
        $user = User::query()->find($transaction->user_id);

        if ($user === null) {
            return;
        }

        $this->spendingCache = [];
        $budgets = Budget::query()->ownedBy($transaction->user_id)
            ->where('period_id', $period->id)
            ->whereIn('category_id', array_unique(array_merge($categoryIds, $parentIds)))
            ->with('category.parent')
            ->lockForUpdate()
            ->get();

        foreach ($budgets as $budget) {
            $row = $this->row($budget, $period);
            $percent = (int) ($row['percent_bp'] ?? ($row['spent_cents'] > 0 ? 10_001 : 0));
            $notified = $budget->notified_threshold ?? 0;

            $threshold = match (true) {
                $percent >= 10_000 && $notified < 100 => 100,
                $percent >= $warning * 100 && $notified < $warning => $warning,
                default => null,
            };

            if ($threshold === null) {
                continue;
            }

            $budget->notified_threshold = $threshold;
            $budget->save();

            $user->notify(new BudgetThresholdReached(
                categoryName: $budget->category->name,
                threshold: $threshold,
                spentCents: (int) $row['spent_cents'],
                availableCents: (int) $row['available_cents'],
                periodId: $period->id,
            ));
        }
    }

    private function rolloverInto(Budget $budget, Period $period, int $depth): int
    {
        if ($depth >= self::MAX_ROLLOVER_DEPTH) {
            return 0;
        }

        $previousPeriod = $this->periods->previous($period);
        if ($previousPeriod === null) {
            return 0;
        }

        $previousBudget = Budget::query()->ownedBy($period->user_id)
            ->where('period_id', $previousPeriod->id)
            ->where('category_id', $budget->category_id)
            ->with('category')
            ->first();

        if ($previousBudget === null) {
            return 0;
        }

        $carried = $previousBudget->rollover ? $this->rolloverInto($previousBudget, $previousPeriod, $depth + 1) : 0;

        return $previousBudget->amount_cents + $carried - $this->spentFor($previousPeriod, $previousBudget->category);
    }

    /**
     * @return array<string, int>
     */
    private function spendingFor(Period $period): array
    {
        return $this->spendingCache[$period->id] ??= $this->spending->ownSpendingByCategory(
            $period->user_id,
            $period->start_date,
            $period->effectiveEndDate(),
        );
    }
}
