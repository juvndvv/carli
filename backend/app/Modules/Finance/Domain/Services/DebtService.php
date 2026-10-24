<?php

namespace App\Modules\Finance\Domain\Services;

use App\Models\User;
use App\Modules\Finance\Domain\Enums\DebtDirection;
use App\Modules\Finance\Domain\Enums\RecurrenceFrequency;
use App\Modules\Finance\Domain\Enums\RecurringMode;
use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class DebtService
{
    public function __construct(
        private readonly RecurringService $recurring,
        private readonly TransactionService $transactions,
    ) {}

    /**
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): Debt
    {
        return DB::transaction(function () use ($user, $data): Debt {
            $debt = new Debt;
            $debt->user_id = $user->id;
            $debt->fill($this->attributes($data));
            $this->assertValid($debt);
            $debt->save();

            if (isset($data['plan']) && is_array($data['plan'])) {
                $this->attachPlan($debt, $data['plan']);
            }

            return $debt->refresh();
        });
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function update(Debt $debt, array $data): Debt
    {
        return DB::transaction(function () use ($debt, $data): Debt {
            $debt->fill($this->attributes($data));

            if (array_key_exists('closed', $data)) {
                $debt->closed_at = $data['closed'] ? ($debt->closed_at ?? CarbonImmutable::now()) : null;
            }

            $this->assertValid($debt);
            $debt->save();

            if (array_key_exists('plan', $data)) {
                $rule = $debt->recurringRule;
                if ($data['plan'] === null && $rule !== null) {
                    $this->recurring->update($rule, ['cancelled' => true]);
                } elseif (is_array($data['plan'])) {
                    if ($rule !== null) {
                        $this->recurring->update($rule, ['cancelled' => true]);
                    }
                    $this->attachPlan($debt, $data['plan']);
                }
            }

            if ($debt->isClosed() && $debt->recurringRule !== null && $debt->recurringRule->cancelled_at === null) {
                $this->recurring->update($debt->recurringRule, ['cancelled' => true]);
            }

            return $debt->refresh();
        });
    }

    public function delete(Debt $debt): void
    {
        DB::transaction(function () use ($debt): void {
            $rule = $debt->recurringRule;
            $debt->delete();
            if ($rule !== null) {
                $this->recurring->delete($rule);
            }
        });
    }

    /**
     * @param  array{account_id: string, amount_cents: int, date?: string|null, category_id?: string|null, description?: string|null, notes?: string|null}  $data
     */
    public function addPayment(Debt $debt, array $data): Transaction
    {
        return DB::transaction(function () use ($debt, $data): Transaction {
            $amount = abs($data['amount_cents']);
            $kind = $debt->direction === DebtDirection::IOwe ? TransactionKind::Expense : TransactionKind::Income;

            $transaction = $this->transactions->create($debt->user_id, [
                'account_id' => $data['account_id'],
                'kind' => $kind->value,
                'amount_cents' => $kind === TransactionKind::Expense ? -$amount : $amount,
                'date' => $data['date'] ?? SpanishCalendar::today()->toDateString(),
                'category_id' => $data['category_id'] ?? null,
                'payee' => $debt->contact->name ?? $debt->name,
                'description' => $data['description'] ?? 'Pago · '.$debt->name,
                'notes' => $data['notes'] ?? null,
                'debt_id' => $debt->id,
            ]);

            $this->closeIfSettled($debt->refresh());

            return $transaction;
        });
    }

    public function closeIfSettled(Debt $debt): void
    {
        if ($debt->closed_at === null && $debt->pendingCents() === 0) {
            $debt->closed_at = CarbonImmutable::now();
            $debt->save();

            $rule = $debt->recurringRule;
            if ($rule !== null && $rule->cancelled_at === null) {
                $this->recurring->update($rule, ['cancelled' => true]);
            }
        }
    }

    public function reopenIfOutstanding(Debt $debt): void
    {
        if ($debt->closed_at !== null && $debt->pendingCents() > 0) {
            $debt->closed_at = null;
            $debt->save();
        }
    }

    /**
     * @param  array<string, mixed>  $plan
     */
    private function attachPlan(Debt $debt, array $plan): void
    {
        $firstPayment = SpanishCalendar::date((string) ($plan['first_payment_date'] ?? $debt->start_date->toDateString()));
        $count = (int) ($plan['installments_count'] ?? 0);
        $installment = abs((int) ($plan['installment_cents'] ?? 0));

        if ($count < 1 || $installment < 1) {
            throw ValidationException::withMessages(['plan' => 'El plan de pagos necesita importe de cuota y número de cuotas.']);
        }

        $dayOfMonth = isset($plan['payment_day']) ? (int) $plan['payment_day'] : $firstPayment->day;
        $schedule = new RecurrenceSchedule(RecurrenceFrequency::Monthly, 1, $firstPayment, null, $dayOfMonth);
        $lastPayment = $schedule->occurrence($count - 1);

        $rule = $this->recurring->create($debt->user_id, [
            'account_id' => $plan['account_id'],
            'category_id' => $plan['category_id'] ?? null,
            'kind' => $debt->direction === DebtDirection::IOwe ? TransactionKind::Expense->value : TransactionKind::Income->value,
            'amount_cents' => $installment,
            'payee' => $debt->contact->name ?? $debt->name,
            'description' => 'Cuota · '.$debt->name,
            'frequency' => RecurrenceFrequency::Monthly->value,
            'interval' => 1,
            'day_of_month' => $dayOfMonth,
            'start_date' => $firstPayment->toDateString(),
            'end_date' => $lastPayment->toDateString(),
            'mode' => (string) ($plan['mode'] ?? RecurringMode::Auto->value),
        ]);

        $debt->recurring_rule_id = $rule->id;
        $debt->installment_cents = $installment;
        $debt->installments_count = $count;
        $debt->save();
    }

    private function assertValid(Debt $debt): void
    {
        if ($debt->contact_id !== null && ! Contact::query()->ownedBy($debt->user_id)->whereKey($debt->contact_id)->exists()) {
            throw ValidationException::withMessages(['contact_id' => 'El contacto no existe.']);
        }
    }

    public function nextPaymentDate(Debt $debt): ?CarbonImmutable
    {
        $rule = $debt->recurringRule;

        return $rule instanceof RecurringRule && $rule->isActive() ? $rule->next_occurrence : null;
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function attributes(array $data): array
    {
        return array_intersect_key($data, array_flip(['contact_id', 'name', 'direction', 'principal_cents', 'start_date', 'due_date', 'notes']));
    }
}
