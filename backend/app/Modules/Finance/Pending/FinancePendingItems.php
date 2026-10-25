<?php

namespace App\Modules\Finance\Pending;

use App\Core\Pending\PendingItem;
use App\Core\Pending\PendingItemsProvider;
use App\Core\Pending\PendingPage;
use App\Models\User;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Queries\TransactionCursor;
use Illuminate\Database\Eloquent\Builder;

final class FinancePendingItems implements PendingItemsProvider
{
    public const string MODULE = 'finance';

    public const string UNCATEGORIZED = 'uncategorized_transaction';

    public const string RECURRING = 'recurring_to_confirm';

    public const string UNCATEGORIZED_ROUTE = '/finanzas/movimientos?sin_categoria=1&periodo=todos';

    public const string RECURRING_ROUTE = '/finanzas/recurrentes';

    private const int PAGE_SIZE = 50;

    public function moduleId(): string
    {
        return self::MODULE;
    }

    public function counts(User $user): array
    {
        return [
            self::UNCATEGORIZED => $this->uncategorized($user)->count(),
            self::RECURRING => $this->recurring($user)->count(),
        ];
    }

    public function items(User $user, ?string $type, ?string $cursor): PendingPage
    {
        $segments = [
            self::UNCATEGORIZED => fn (?string $inner) => $this->uncategorizedPage($user, $inner),
            self::RECURRING => fn (?string $inner) => $this->recurringPage($user, $inner),
        ];

        if ($type !== null) {
            $segments = array_intersect_key($segments, [$type => true]);
        }

        return PendingPage::chain($segments, $cursor);
    }

    public function describe(string $type, int $count): string
    {
        return match ($type) {
            self::UNCATEGORIZED => $count === 1 ? '1 movimiento por categorizar' : "{$count} movimientos por categorizar",
            self::RECURRING => $count === 1 ? '1 recurrente por confirmar' : "{$count} recurrentes por confirmar",
            default => $count === 1 ? '1 pendiente' : "{$count} pendientes",
        };
    }

    /**
     * @return Builder<Transaction>
     */
    private function uncategorized(User $user): Builder
    {
        return Transaction::query()->ownedBy($user)->uncategorized();
    }

    /**
     * @return Builder<Transaction>
     */
    private function recurring(User $user): Builder
    {
        return Transaction::query()->ownedBy($user)
            ->whereNotNull('recurring_rule_id')
            ->where('status', TransactionStatus::Pending->value);
    }

    private function uncategorizedPage(User $user, ?string $cursor): PendingPage
    {
        $query = $this->uncategorized($user)->with('account');
        $position = TransactionCursor::decode($cursor);

        if ($position !== null) {
            $query->whereRaw('(date, id) < (?::date, ?::uuid)', [$position['date'], $position['id']]);
        }

        $rows = $query->orderByDesc('date')->orderByDesc('id')->limit(self::PAGE_SIZE + 1)->get();

        return $this->paginate(array_values($rows->all()), fn (Transaction $transaction) => new PendingItem(
            module: self::MODULE,
            type: self::UNCATEGORIZED,
            id: $transaction->id,
            title: $transaction->payee ?? $transaction->description ?? 'Movimiento',
            date: $transaction->date->toDateString(),
            route: self::UNCATEGORIZED_ROUTE,
            subtitle: $transaction->account->name.($transaction->source === TransactionSource::Bank ? ' · Importado del banco' : ''),
            amountCents: $transaction->amount_cents,
            meta: [
                'transaction_id' => $transaction->id,
                'kind' => $transaction->kind->value,
                'account_id' => $transaction->account_id,
                'source' => $transaction->source->value,
                'payee' => $transaction->payee,
                'description' => $transaction->description,
            ],
        ));
    }

    private function recurringPage(User $user, ?string $cursor): PendingPage
    {
        $query = $this->recurring($user)->with(['account', 'recurringRule']);
        $position = TransactionCursor::decode($cursor);

        if ($position !== null) {
            $query->whereRaw('(date, id) > (?::date, ?::uuid)', [$position['date'], $position['id']]);
        }

        $rows = $query->orderBy('date')->orderBy('id')->limit(self::PAGE_SIZE + 1)->get();

        return $this->paginate(array_values($rows->all()), fn (Transaction $transaction) => new PendingItem(
            module: self::MODULE,
            type: self::RECURRING,
            id: $transaction->id,
            title: $transaction->recurringRule?->displayName() ?? $transaction->payee ?? $transaction->description ?? 'Recurrente',
            date: $transaction->date->toDateString(),
            route: self::RECURRING_ROUTE,
            subtitle: $transaction->account->name.' · Por confirmar',
            amountCents: $transaction->amount_cents,
            meta: [
                'transaction_id' => $transaction->id,
                'rule_id' => $transaction->recurring_rule_id,
                'kind' => $transaction->kind->value,
                'account_id' => $transaction->account_id,
                'category_id' => $transaction->category_id,
            ],
        ));
    }

    /**
     * @param  list<Transaction>  $rows
     * @param  callable(Transaction): PendingItem  $present
     */
    private function paginate(array $rows, callable $present): PendingPage
    {
        $page = array_slice($rows, 0, self::PAGE_SIZE);
        $last = end($page);

        return new PendingPage(
            array_map($present, $page),
            count($rows) > self::PAGE_SIZE && $last !== false ? TransactionCursor::encode($last) : null,
        );
    }
}
