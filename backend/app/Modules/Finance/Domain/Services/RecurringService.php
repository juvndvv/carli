<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\RecurrenceFrequency;
use App\Modules\Finance\Domain\Enums\RecurringMode;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class RecurringService
{
    private const array SCHEDULE_FIELDS = ['frequency', 'interval', 'day_of_month', 'start_date', 'end_date'];

    private const array ATTRIBUTES = [
        'account_id', 'category_id', 'kind', 'amount_cents', 'payee', 'description', 'frequency', 'interval',
        'day_of_month', 'start_date', 'end_date', 'mode', 'remind_days_before', 'is_subscription',
    ];

    public function __construct(
        private readonly TransactionService $transactions,
        private readonly FinanceSettingsService $settings,
        private readonly PeriodService $periods,
    ) {}

    public static function schedule(RecurringRule $rule): RecurrenceSchedule
    {
        return new RecurrenceSchedule($rule->frequency, $rule->interval, $rule->start_date, $rule->end_date, $rule->day_of_month);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User|string $user, array $data): RecurringRule
    {
        $userId = $user instanceof User ? $user->id : $user;
        $rule = new RecurringRule;
        $rule->user_id = $userId;
        $rule->remind_days_before = $this->settings->for($userId)->remind_days_before;
        $rule->fill(array_intersect_key($data, array_flip(self::ATTRIBUTES)));
        $this->assertValid($rule);
        $rule->next_occurrence = self::schedule($rule)->first();
        $rule->save();

        $this->refreshOpenPeriod($userId);

        return $rule->refresh();
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(RecurringRule $rule, array $data): RecurringRule
    {
        $rule->fill(array_intersect_key($data, array_flip(self::ATTRIBUTES)));

        if (array_key_exists('cancelled', $data)) {
            $rule->cancelled_at = $data['cancelled'] ? ($rule->cancelled_at ?? CarbonImmutable::now()) : null;
        }

        $this->assertValid($rule);

        if ($rule->isDirty(self::SCHEDULE_FIELDS) || ($rule->isDirty('cancelled_at') && $rule->cancelled_at === null)) {
            $from = $rule->transactions()->exists()
                ? SpanishCalendar::today()->max($rule->start_date)
                : $rule->start_date;
            $rule->next_occurrence = self::schedule($rule)->firstOnOrAfter($from);
        }

        $rule->save();
        $this->refreshOpenPeriod($rule->user_id);

        return $rule->refresh();
    }

    public function delete(RecurringRule $rule): void
    {
        DB::transaction(function () use ($rule): void {
            Transaction::query()->withoutGlobalScopes()
                ->where('recurring_rule_id', $rule->id)
                ->where('status', TransactionStatus::Pending->value)
                ->get()
                ->each(fn (Transaction $transaction) => $this->transactions->delete($transaction));
            $rule->delete();
        });

        $this->refreshOpenPeriod($rule->user_id);
    }

    public function materializeDue(?CarbonImmutable $today = null): int
    {
        $today ??= SpanishCalendar::today();
        $created = 0;

        RecurringRule::query()->withoutGlobalScopes()
            ->whereNull('cancelled_at')
            ->whereNotNull('next_occurrence')
            ->where('next_occurrence', '<=', $today->toDateString())
            ->orderBy('next_occurrence')
            ->pluck('id')
            ->each(function (string $ruleId) use ($today, &$created): void {
                $created += $this->materialize($ruleId, $today);
            });

        return $created;
    }

    public function materialize(string $ruleId, CarbonImmutable $until): int
    {
        return DB::transaction(function () use ($ruleId, $until): int {
            $rule = RecurringRule::query()->withoutGlobalScopes()->whereKey($ruleId)->lockForUpdate()->first();

            if ($rule === null || ! $rule->isActive()) {
                return 0;
            }

            $created = 0;
            $schedule = self::schedule($rule);
            $status = $rule->mode === RecurringMode::Auto && ! $rule->awaitsBank() ? TransactionStatus::Cleared : TransactionStatus::Pending;

            while ($rule->next_occurrence !== null && $rule->next_occurrence->lessThanOrEqualTo($until)) {
                $date = $rule->next_occurrence;

                if (! $this->occurrenceExists($rule, $date)) {
                    $this->createOccurrence($rule, $date, $status, $rule->amount_cents);
                    $created++;
                }

                $rule->next_occurrence = $schedule->after($date);
            }

            $rule->save();
            $this->refreshOpenPeriod($rule->user_id);

            return $created;
        });
    }

    /**
     * @param  array{amount_cents?: int|null, date?: string|null, update_rule_amount?: bool|null}  $data
     * @return array{transaction: Transaction, price_changed: bool, previous_amount_cents: int}
     */
    public function confirm(RecurringRule $rule, array $data): array
    {
        return DB::transaction(function () use ($rule, $data): array {
            $rule = RecurringRule::query()->withoutGlobalScopes()->whereKey($rule->id)->lockForUpdate()->firstOrFail();
            $expected = $rule->amount_cents;
            $amount = isset($data['amount_cents']) ? $this->signed($rule->kind, (int) $data['amount_cents']) : null;

            $pending = Transaction::query()->ownedBy($rule->user_id)
                ->where('recurring_rule_id', $rule->id)
                ->where('status', TransactionStatus::Pending->value)
                ->orderBy('date')
                ->first();

            if ($pending !== null) {
                $changes = ['status' => TransactionStatus::Cleared->value];
                if ($amount !== null) {
                    $changes['amount_cents'] = $amount;
                }
                if (isset($data['date'])) {
                    $changes['date'] = $data['date'];
                }
                $transaction = $this->transactions->update($pending, $changes);
            } else {
                if (! $rule->isActive() || $rule->next_occurrence === null) {
                    throw ValidationException::withMessages(['rule' => 'Esta regla no tiene ocurrencias pendientes.']);
                }

                $occurrence = $rule->next_occurrence;
                $transaction = $this->createOccurrence($rule, $occurrence, TransactionStatus::Cleared, $amount ?? $expected, $data['date'] ?? null);
                $rule->next_occurrence = self::schedule($rule)->after($occurrence);
            }

            $priceChanged = $transaction->amount_cents !== $expected;

            if ($priceChanged && ($data['update_rule_amount'] ?? false)) {
                $rule->amount_cents = $transaction->amount_cents;
            }

            $rule->save();
            $this->refreshOpenPeriod($rule->user_id);

            return ['transaction' => $transaction, 'price_changed' => $priceChanged, 'previous_amount_cents' => $expected];
        });
    }

    /**
     * @return list<array{rule: RecurringRule, date: CarbonImmutable}>
     */
    public function upcoming(User|string $user, int $days, ?CarbonImmutable $today = null): array
    {
        $today ??= SpanishCalendar::today();
        $until = $today->addDays($days);
        $upcoming = [];

        $rules = RecurringRule::query()->ownedBy($user)
            ->whereNull('cancelled_at')
            ->whereNotNull('next_occurrence')
            ->where('next_occurrence', '<=', $until->toDateString())
            ->with(['category.parent', 'account'])
            ->get();

        foreach ($rules as $rule) {
            foreach (self::schedule($rule)->between($rule->next_occurrence ?? $today, $until) as $date) {
                if ($date->greaterThanOrEqualTo($today)) {
                    $upcoming[] = ['rule' => $rule, 'date' => $date];
                }
            }
        }

        usort($upcoming, fn (array $left, array $right) => $left['date'] <=> $right['date']);

        return $upcoming;
    }

    /**
     * @return Collection<int, Transaction>
     */
    public function pendingTransactions(User|string $user): Collection
    {
        return Transaction::query()->ownedBy($user)
            ->whereNotNull('recurring_rule_id')
            ->where('status', TransactionStatus::Pending->value)
            ->orderBy('date')
            ->get();
    }

    public static function monthlyCostCents(RecurringRule $rule): int
    {
        $amount = Money::ofCents($rule->amount_cents);
        $interval = max(1, $rule->interval);

        return match ($rule->frequency) {
            RecurrenceFrequency::Daily => $amount->multiply(365, 12 * $interval)->cents,
            RecurrenceFrequency::Weekly => $amount->multiply(52, 12 * $interval)->cents,
            RecurrenceFrequency::Monthly => $amount->multiply(1, $interval)->cents,
            RecurrenceFrequency::Yearly => $amount->multiply(1, 12 * $interval)->cents,
        };
    }

    public static function yearlyCostCents(RecurringRule $rule): int
    {
        $amount = Money::ofCents($rule->amount_cents);
        $interval = max(1, $rule->interval);

        return match ($rule->frequency) {
            RecurrenceFrequency::Daily => $amount->multiply(365, $interval)->cents,
            RecurrenceFrequency::Weekly => $amount->multiply(52, $interval)->cents,
            RecurrenceFrequency::Monthly => $amount->multiply(12, $interval)->cents,
            RecurrenceFrequency::Yearly => $amount->multiply(1, $interval)->cents,
        };
    }

    private function occurrenceExists(RecurringRule $rule, CarbonImmutable $date): bool
    {
        return Transaction::query()->withoutGlobalScopes()->withTrashed()
            ->where('recurring_rule_id', $rule->id)
            ->where('recurring_date', $date->toDateString())
            ->exists();
    }

    private function createOccurrence(RecurringRule $rule, CarbonImmutable $occurrence, TransactionStatus $status, int $amount, ?string $date = null): Transaction
    {
        $debtId = $rule->debt()->value('id');

        return $this->transactions->create($rule->user_id, [
            'account_id' => $rule->account_id,
            'kind' => $rule->kind->value,
            'amount_cents' => $amount,
            'date' => $date ?? $occurrence->toDateString(),
            'category_id' => $rule->category_id,
            'payee' => $rule->payee,
            'description' => $rule->description,
            'status' => $status->value,
            'debt_id' => is_string($debtId) ? $debtId : null,
        ], $rule->id, $occurrence->toDateString());
    }

    private function signed(TransactionKind $kind, int $amount): int
    {
        return $kind === TransactionKind::Expense ? -abs($amount) : abs($amount);
    }

    private function assertValid(RecurringRule $rule): void
    {
        $errors = [];

        if (! in_array($rule->kind, [TransactionKind::Expense, TransactionKind::Income], true)) {
            $errors['kind'] = 'Las reglas recurrentes solo admiten gastos o ingresos.';
        } else {
            $rule->amount_cents = $this->signed($rule->kind, $rule->amount_cents);
        }

        if ($rule->amount_cents === 0) {
            $errors['amount_cents'] = 'El importe no puede ser cero.';
        }

        if (! Account::query()->ownedBy($rule->user_id)->whereKey($rule->account_id)->exists()) {
            $errors['account_id'] = 'La cuenta no existe.';
        }

        if ($rule->category_id !== null) {
            $category = Category::query()->ownedBy($rule->user_id)->whereKey($rule->category_id)->first();
            if ($category === null || $category->kind->value !== $rule->kind->value) {
                $errors['category_id'] = 'La categoría no corresponde al tipo de movimiento.';
            }
        }

        if ($rule->end_date !== null && $rule->end_date->lessThan($rule->start_date)) {
            $errors['end_date'] = 'La fecha de fin debe ser posterior a la de inicio.';
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }
    }

    private function refreshOpenPeriod(string $userId): void
    {
        $open = Period::query()->ownedBy($userId)->whereNull('end_date')->first();

        if ($open !== null) {
            $this->periods->refreshExpectedEnd($open);
        }
    }
}
