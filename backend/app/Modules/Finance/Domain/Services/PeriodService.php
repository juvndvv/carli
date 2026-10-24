<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\PeriodMode;
use App\Modules\Finance\Domain\Enums\PeriodOpenedBy;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Support\PeriodRange;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class PeriodService
{
    public function __construct(private readonly FinanceSettingsService $settings) {}

    /**
     * @return Collection<int, Period>
     */
    public function all(User|string $user): Collection
    {
        $this->current($user);

        return Period::query()->ownedBy($user)->orderByDesc('start_date')->get();
    }

    public function current(User|string $user): Period
    {
        $userId = $this->userId($user);
        $open = $this->openPeriod($userId);
        $today = SpanishCalendar::today();

        $needsCalendarRollover = $open !== null
            && $this->settings->for($userId)->period_mode === PeriodMode::Calendar
            && $open->start_date->startOfMonth()->lessThan($today->startOfMonth());

        if ($open === null || $needsCalendarRollover || $this->hasArrivedPayroll($open, $today)) {
            DB::transaction(function () use ($userId, $open): void {
                $this->settings->lockFor($userId);
                if ($open === null) {
                    $this->bootstrap($userId, null);
                } else {
                    $this->rebuild($userId);
                }
            });
            $open = $this->openPeriod($userId);
        }

        if ($open === null) {
            throw new \LogicException('An open period must exist after bootstrapping.');
        }

        $this->refreshExpectedEnd($open);

        return $open;
    }

    public function find(User|string $user, string $periodId): ?Period
    {
        return Period::query()->ownedBy($user)->whereKey($periodId)->first();
    }

    public function forDate(User|string $user, CarbonImmutable $date): ?Period
    {
        return Period::query()
            ->ownedBy($user)
            ->where('start_date', '<=', $date->toDateString())
            ->where(fn ($query) => $query->whereNull('end_date')->orWhere('end_date', '>=', $date->toDateString()))
            ->first();
    }

    public function previous(Period $period): ?Period
    {
        return Period::query()
            ->ownedBy($period->user_id)
            ->where('start_date', '<', $period->start_date->toDateString())
            ->orderByDesc('start_date')
            ->first();
    }

    public function next(Period $period): ?Period
    {
        return Period::query()
            ->ownedBy($period->user_id)
            ->where('start_date', '>', $period->start_date->toDateString())
            ->orderBy('start_date')
            ->first();
    }

    /**
     * @return Collection<int, Period>
     */
    public function lastPeriods(Period $period, int $count): Collection
    {
        return Period::query()
            ->ownedBy($period->user_id)
            ->where('start_date', '<=', $period->start_date->toDateString())
            ->orderByDesc('start_date')
            ->limit($count)
            ->get()
            ->reverse()
            ->values();
    }

    public function isPayroll(Transaction $transaction): bool
    {
        if ($transaction->trashed()
            || $transaction->kind !== TransactionKind::Income
            || $transaction->status !== TransactionStatus::Cleared
            || $transaction->category_id === null) {
            return false;
        }

        if ($this->settings->for($transaction->user_id)->period_mode !== PeriodMode::Payroll) {
            return false;
        }

        return Category::query()->ownedBy($transaction->user_id)->whereKey($transaction->category_id)->where('opens_period', true)->exists();
    }

    public function ensureBootstrapped(User|string $user, ?Transaction $trigger = null): void
    {
        $userId = $this->userId($user);

        if (Period::query()->ownedBy($userId)->exists()) {
            return;
        }

        DB::transaction(function () use ($userId, $trigger): void {
            $this->settings->lockFor($userId);
            if (! Period::query()->ownedBy($userId)->exists()) {
                $this->bootstrap($userId, $trigger);
            }
        });
    }

    public function handlePayroll(Transaction $transaction): bool
    {
        if (! $this->isPayroll($transaction)) {
            return false;
        }

        return DB::transaction(function () use ($transaction): bool {
            $userId = $transaction->user_id;
            $this->settings->lockFor($userId);

            if (! Period::query()->ownedBy($userId)->exists()) {
                $this->bootstrap($userId, $transaction);

                return true;
            }

            return $this->rebuild($userId);
        });
    }

    public function openManual(User|string $user, CarbonImmutable $start): Period
    {
        $userId = $this->userId($user);
        $this->current($userId);

        return DB::transaction(function () use ($userId, $start): Period {
            $this->settings->lockFor($userId);
            $period = $this->forDate($userId, $start);

            if ($period === null) {
                $earliest = Period::query()->ownedBy($userId)->orderBy('start_date')->firstOrFail();

                return $this->createPeriod($userId, $start, $earliest->start_date->subDay(), PeriodOpenedBy::Manual, null);
            }

            if ($period->start_date->equalTo($start)) {
                throw ValidationException::withMessages(['start_date' => 'Ya existe un periodo que empieza ese día.']);
            }

            return $this->split($period, $start, PeriodOpenedBy::Manual, null);
        });
    }

    public function moveStart(Period $period, CarbonImmutable $start): Period
    {
        return DB::transaction(function () use ($period, $start): Period {
            $this->settings->lockFor($period->user_id);
            $period->refresh();

            if ($period->start_date->equalTo($start)) {
                return $period;
            }

            $previous = $this->previous($period);

            if ($previous !== null && $start->lessThanOrEqualTo($previous->start_date)) {
                throw ValidationException::withMessages(['start_date' => 'La fecha debe ser posterior al inicio del periodo anterior.']);
            }

            if ($period->end_date !== null && $start->greaterThan($period->end_date)) {
                throw ValidationException::withMessages(['start_date' => 'La fecha no puede ser posterior al final del periodo.']);
            }

            $this->deferConstraints();

            if ($previous !== null && $previous->end_date !== null && $previous->end_date->addDay()->equalTo($period->start_date)) {
                $previous->end_date = $start->subDay();
                $previous->save();
            }

            $period->start_date = $start;
            $period->opened_by = PeriodOpenedBy::Manual;
            $period->save();

            $this->enforceConstraints();
            $this->refreshExpectedEnd($period);

            return $period;
        });
    }

    public function rebuild(User|string $user): bool
    {
        $userId = $this->userId($user);

        return DB::transaction(function () use ($userId): bool {
            $this->settings->lockFor($userId);
            $existing = Period::query()->ownedBy($userId)->orderBy('start_date')->get();
            $ranges = $this->settings->for($userId)->period_mode === PeriodMode::Calendar
                ? $this->calendarRanges($userId, $existing)
                : $this->payrollRanges($userId, $existing);

            $changed = $this->persist($userId, $existing, $ranges);

            $open = $this->openPeriod($userId);
            if ($open !== null) {
                $this->refreshExpectedEnd($open);
            }

            return $changed;
        });
    }

    /**
     * @return list<array{start: string, end: string|null}>
     */
    public function signature(User|string $user): array
    {
        $signature = [];
        foreach (Period::query()->ownedBy($user)->orderBy('start_date')->get() as $period) {
            $signature[] = ['start' => $period->start_date->toDateString(), 'end' => $period->end_date?->toDateString()];
        }

        return $signature;
    }

    public function refreshExpectedEnd(Period $period): void
    {
        $expected = $period->isOpen() ? $this->expectedEnd($period) : null;

        if ($period->expected_end_date?->toDateString() !== $expected?->toDateString()) {
            $period->expected_end_date = $expected;
            $period->save();
        }
    }

    public function expectedNextPayrollDate(Period $period): ?CarbonImmutable
    {
        if ($this->settings->for($period->user_id)->period_mode === PeriodMode::Calendar) {
            return null;
        }

        $earliestOpening = $period->start_date->addDays($this->settings->for($period->user_id)->period_min_days);
        $candidates = [];

        $rules = RecurringRule::query()
            ->ownedBy($period->user_id)
            ->whereNull('cancelled_at')
            ->where('kind', TransactionKind::Income->value)
            ->whereNotNull('next_occurrence')
            ->whereIn('category_id', $this->payrollCategoryIds($period->user_id))
            ->get();

        foreach ($rules as $rule) {
            if ($rule->next_occurrence === null) {
                continue;
            }
            $candidates[] = RecurringService::schedule($rule)->firstOnOrAfter($rule->next_occurrence->max($earliestOpening));
        }

        $awaitedPayroll = Transaction::query()
            ->ownedBy($period->user_id)
            ->where('kind', TransactionKind::Income->value)
            ->whereIn('category_id', $this->payrollCategoryIds($period->user_id))
            ->where('date', '>=', $earliestOpening->toDateString())
            ->where(fn ($query) => $query
                ->where('status', TransactionStatus::Pending->value)
                ->orWhere('date', '>', SpanishCalendar::today()->toDateString()))
            ->min('date');

        if (is_string($awaitedPayroll)) {
            $candidates[] = SpanishCalendar::date($awaitedPayroll);
        }

        $expected = null;
        foreach ($candidates as $candidate) {
            if ($candidate !== null && ($expected === null || $candidate->lessThan($expected))) {
                $expected = $candidate;
            }
        }

        return $expected ?? $period->start_date->addMonthNoOverflow();
    }

    private function hasArrivedPayroll(Period $open, CarbonImmutable $today): bool
    {
        $settings = $this->settings->for($open->user_id);

        if ($settings->period_mode !== PeriodMode::Payroll) {
            return false;
        }

        return Transaction::query()
            ->ownedBy($open->user_id)
            ->where('kind', TransactionKind::Income->value)
            ->where('status', TransactionStatus::Cleared->value)
            ->whereIn('category_id', $this->payrollCategoryIds($open->user_id))
            ->whereNotIn('id', $this->supersededPayrollIds($open->user_id))
            ->where('date', '>=', $open->start_date->addDays($settings->period_min_days)->toDateString())
            ->where('date', '<=', $today->toDateString())
            ->exists();
    }

    /**
     * @return Builder<Category>
     */
    private function payrollCategoryIds(string $userId): Builder
    {
        return Category::query()->ownedBy($userId)->where('opens_period', true)->select('id');
    }

    /**
     * @return Builder<Period>
     */
    private function supersededPayrollIds(string $userId): Builder
    {
        return Period::query()
            ->ownedBy($userId)
            ->where('opened_by', PeriodOpenedBy::Manual->value)
            ->whereNotNull('opening_transaction_id')
            ->select('opening_transaction_id');
    }

    private function expectedEnd(Period $period): CarbonImmutable
    {
        if ($this->settings->for($period->user_id)->period_mode === PeriodMode::Calendar) {
            return $period->start_date->endOfMonth()->startOfDay();
        }

        return ($this->expectedNextPayrollDate($period) ?? $period->start_date->addMonthNoOverflow())->subDay();
    }

    private function bootstrap(string $userId, ?Transaction $trigger): void
    {
        if ($this->settings->for($userId)->period_mode === PeriodMode::Calendar) {
            $this->rebuild($userId);

            return;
        }

        if ($trigger !== null && $this->isPayroll($trigger) && $trigger->date->lessThanOrEqualTo(SpanishCalendar::today())) {
            $this->createPeriod($userId, $trigger->date, null, PeriodOpenedBy::Payroll, $trigger->id);

            return;
        }

        $payrolls = $this->payrollTransactions($userId);
        if ($payrolls->isNotEmpty()) {
            $this->rebuild($userId);

            return;
        }

        $this->createPeriod($userId, $this->bootstrapStart($userId), null, PeriodOpenedBy::Calendar, null);
    }

    private function bootstrapStart(string $userId): CarbonImmutable
    {
        $start = SpanishCalendar::today()->startOfMonth();
        $earliest = $this->earliestTransactionDate($userId);

        return $earliest !== null && $earliest->lessThan($start) ? $earliest : $start;
    }

    private function earliestTransactionDate(string $userId): ?CarbonImmutable
    {
        $earliest = Transaction::query()->ownedBy($userId)->min('date');

        return is_string($earliest) ? SpanishCalendar::date($earliest) : null;
    }

    /**
     * @return Collection<int, Transaction>
     */
    private function payrollTransactions(string $userId): Collection
    {
        return Transaction::query()
            ->ownedBy($userId)
            ->where('kind', TransactionKind::Income->value)
            ->where('status', TransactionStatus::Cleared->value)
            ->whereIn('category_id', $this->payrollCategoryIds($userId))
            ->whereNotIn('id', $this->supersededPayrollIds($userId))
            ->where('date', '<=', SpanishCalendar::today()->toDateString())
            ->orderBy('date')
            ->orderBy('created_at')
            ->get();
    }

    /**
     * @param  Collection<int, Period>  $existing
     * @return list<PeriodRange>
     */
    private function payrollRanges(string $userId, Collection $existing): array
    {
        $minDays = $this->settings->for($userId)->period_min_days;
        $events = [];

        foreach ($existing as $period) {
            if ($period->opened_by === PeriodOpenedBy::Manual) {
                $events[] = ['date' => $period->start_date, 'manual' => true, 'transaction' => $period->opening_transaction_id];
            }
        }

        foreach ($this->payrollTransactions($userId) as $payroll) {
            $events[] = ['date' => $payroll->date, 'manual' => false, 'transaction' => $payroll->id];
        }

        $earliestEvent = null;
        foreach ($events as $event) {
            if ($earliestEvent === null || $event['date']->lessThan($earliestEvent)) {
                $earliestEvent = $event['date'];
            }
        }

        $initial = $existing->first();
        $softStart = $initial !== null && $initial->opened_by === PeriodOpenedBy::Calendar ? $initial->start_date : null;
        if ($events === [] && $softStart === null) {
            $softStart = $this->bootstrapStart($userId);
        }

        if ($softStart !== null && ($earliestEvent === null || $softStart->lessThan($earliestEvent))) {
            $events[] = ['date' => $softStart, 'manual' => true, 'transaction' => null, 'soft' => true];
        }

        usort($events, fn (array $left, array $right) => [$left['date']->toDateString(), $left['manual'] ? 0 : 1] <=> [$right['date']->toDateString(), $right['manual'] ? 0 : 1]);

        $ranges = [];
        foreach ($events as $event) {
            $last = $ranges === [] ? null : $ranges[array_key_last($ranges)];

            if ($last === null) {
                $openedBy = match (true) {
                    $event['soft'] ?? false => PeriodOpenedBy::Calendar,
                    $event['manual'] => PeriodOpenedBy::Manual,
                    default => PeriodOpenedBy::Payroll,
                };
                $ranges[] = new PeriodRange($event['date'], $openedBy, $event['transaction']);

                continue;
            }

            if ($last->start->equalTo($event['date'])) {
                if ($last->openingTransactionId === null && $event['transaction'] !== null) {
                    $last->openingTransactionId = $event['transaction'];
                    if ($last->openedBy === PeriodOpenedBy::Calendar) {
                        $last->openedBy = PeriodOpenedBy::Payroll;
                    }
                }

                continue;
            }

            if ($event['manual'] || $last->start->diffInDays($event['date']) >= $minDays) {
                $ranges[] = new PeriodRange($event['date'], $event['manual'] ? PeriodOpenedBy::Manual : PeriodOpenedBy::Payroll, $event['transaction']);
            }
        }

        return $this->closeRanges($ranges);
    }

    /**
     * @param  Collection<int, Period>  $existing
     * @return list<PeriodRange>
     */
    private function calendarRanges(string $userId, Collection $existing): array
    {
        $today = SpanishCalendar::today();
        $earliest = $today;
        foreach ([$existing->first()?->start_date, $this->earliestTransactionDate($userId)] as $candidate) {
            if ($candidate !== null && $candidate->lessThan($earliest)) {
                $earliest = $candidate;
            }
        }
        $cursor = $earliest->startOfMonth();

        $ranges = [];
        while ($cursor->lessThanOrEqualTo($today)) {
            $ranges[] = new PeriodRange($cursor, PeriodOpenedBy::Calendar);
            $cursor = $cursor->addMonthNoOverflow();
        }

        return $this->closeRanges($ranges);
    }

    /**
     * @param  list<PeriodRange>  $ranges
     * @return list<PeriodRange>
     */
    private function closeRanges(array $ranges): array
    {
        foreach ($ranges as $index => $range) {
            $range->end = isset($ranges[$index + 1]) ? $ranges[$index + 1]->start->subDay() : null;
        }

        return $ranges;
    }

    /**
     * @param  Collection<int, Period>  $existing
     * @param  list<PeriodRange>  $ranges
     */
    private function persist(string $userId, Collection $existing, array $ranges): bool
    {
        $byStart = $existing->keyBy(fn (Period $period) => $period->start_date->toDateString());
        $assigned = [];
        $unclaimed = $existing->filter(fn (Period $period) => ! in_array(
            $period->start_date->toDateString(),
            array_map(fn (PeriodRange $range) => $range->start->toDateString(), $ranges),
            true,
        ))->values();

        foreach ($ranges as $index => $range) {
            $match = $byStart->get($range->start->toDateString());

            if ($match === null) {
                $match = $unclaimed->first(fn (Period $period) => $range->overlaps($period->start_date, $period->end_date));
                if ($match !== null) {
                    $unclaimed = $unclaimed->reject(fn (Period $period) => $period->is($match))->values();
                }
            }

            $assigned[$index] = $match;
        }

        $changed = false;
        $this->deferConstraints();

        $created = [];
        foreach ($ranges as $index => $range) {
            $period = $assigned[$index] ?? null;

            if ($period === null) {
                $period = new Period;
                $period->user_id = $userId;
                $created[] = $index;
            }

            $period->start_date = $range->start;
            $period->end_date = $range->end;
            $period->opened_by = $range->openedBy;
            $period->opening_transaction_id = $range->openingTransactionId;
            if ($range->end !== null) {
                $period->expected_end_date = null;
            }

            if ($period->isDirty(['start_date', 'end_date']) || ! $period->exists) {
                $changed = true;
            }

            $period->save();
            $assigned[$index] = $period;
        }

        foreach ($unclaimed as $orphan) {
            $heir = $this->heirOf($orphan, $ranges, $assigned);
            if ($heir !== null) {
                $this->inheritBudgets($orphan, $heir);
            }
            $orphan->delete();
            $changed = true;
        }

        $this->enforceConstraints();

        foreach ($created as $index) {
            $source = $assigned[$index - 1] ?? null;
            $target = $assigned[$index];
            if ($source !== null && $target !== null) {
                $this->copyBudgets($source, $target);
            }
        }

        return $changed;
    }

    /**
     * @param  list<PeriodRange>  $ranges
     * @param  array<int, Period|null>  $assigned
     */
    private function heirOf(Period $orphan, array $ranges, array $assigned): ?Period
    {
        $heir = $assigned[0] ?? null;

        foreach ($ranges as $index => $range) {
            if ($range->start->lessThanOrEqualTo($orphan->start_date)) {
                $heir = $assigned[$index] ?? $heir;
            }
        }

        return $heir;
    }

    private function inheritBudgets(Period $orphan, Period $heir): void
    {
        $taken = Budget::query()->ownedBy($heir->user_id)->where('period_id', $heir->id)->pluck('category_id')->all();

        Budget::query()->ownedBy($orphan->user_id)
            ->where('period_id', $orphan->id)
            ->whereNotIn('category_id', $taken)
            ->update(['period_id' => $heir->id]);
    }

    private function split(Period $period, CarbonImmutable $start, PeriodOpenedBy $openedBy, ?string $transactionId): Period
    {
        $originalEnd = $period->end_date;
        $period->end_date = $start->subDay();
        $period->save();
        $this->refreshExpectedEnd($period);

        $created = $this->createPeriod($period->user_id, $start, $originalEnd, $openedBy, $transactionId);
        $this->copyBudgets($period, $created);

        return $created;
    }

    private function createPeriod(string $userId, CarbonImmutable $start, ?CarbonImmutable $end, PeriodOpenedBy $openedBy, ?string $transactionId): Period
    {
        $period = new Period([
            'start_date' => $start,
            'end_date' => $end,
            'opened_by' => $openedBy,
            'opening_transaction_id' => $transactionId,
        ]);
        $period->user_id = $userId;
        $period->save();
        $this->refreshExpectedEnd($period);

        return $period;
    }

    public function copyBudgets(Period $from, Period $to): int
    {
        $existing = Budget::query()->ownedBy($to->user_id)->where('period_id', $to->id)->pluck('category_id')->all();
        $copied = 0;

        foreach (Budget::query()->ownedBy($from->user_id)->where('period_id', $from->id)->get() as $budget) {
            if (in_array($budget->category_id, $existing, true)) {
                continue;
            }

            $copy = new Budget([
                'category_id' => $budget->category_id,
                'period_id' => $to->id,
                'amount_cents' => $budget->amount_cents,
                'rollover' => $budget->rollover,
            ]);
            $copy->user_id = $to->user_id;
            $copy->save();
            $copied++;
        }

        return $copied;
    }

    private function openPeriod(string $userId): ?Period
    {
        return Period::query()->ownedBy($userId)->whereNull('end_date')->first();
    }

    private function deferConstraints(): void
    {
        DB::statement('SET CONSTRAINTS finance.periods_user_start_unique, finance.periods_no_overlap DEFERRED');
    }

    private function enforceConstraints(): void
    {
        DB::statement('SET CONSTRAINTS finance.periods_user_start_unique, finance.periods_no_overlap IMMEDIATE');
    }

    private function userId(User|string $user): string
    {
        return $user instanceof User ? $user->id : $user;
    }
}
