<?php

namespace App\Modules\Finance\tests\Support;

use App\Models\User;
use App\Modules\Finance\Domain\Services\FinanceBootstrapper;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Services\TransferService;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Transaction;

final class FinanceFixtures
{
    public static function user(): User
    {
        $user = User::factory()->create();
        app(FinanceBootstrapper::class)->ensure($user);

        return $user;
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public static function account(User $user, array $attributes = []): Account
    {
        $account = new Account(array_merge([
            'name' => 'Cuenta corriente',
            'type' => 'checking',
            'initial_balance_cents' => 0,
        ], $attributes));
        $account->user_id = $user->id;
        $account->save();

        return $account;
    }

    public static function category(User $user, string $name): Category
    {
        return Category::query()->ownedBy($user)->where('name', $name)->firstOrFail();
    }

    /**
     * @param  array<string, mixed>  $extra
     */
    public static function expense(User $user, Account $account, int $cents, string $date, ?string $category = 'Supermercado', array $extra = []): Transaction
    {
        return app(TransactionService::class)->create($user, array_merge([
            'account_id' => $account->id,
            'kind' => 'expense',
            'amount_cents' => -abs($cents),
            'date' => $date,
            'category_id' => $category === null ? null : self::category($user, $category)->id,
        ], $extra));
    }

    /**
     * @param  array<string, mixed>  $extra
     */
    public static function income(User $user, Account $account, int $cents, string $date, ?string $category = 'Nómina', array $extra = []): Transaction
    {
        return app(TransactionService::class)->create($user, array_merge([
            'account_id' => $account->id,
            'kind' => 'income',
            'amount_cents' => abs($cents),
            'date' => $date,
            'category_id' => $category === null ? null : self::category($user, $category)->id,
        ], $extra));
    }

    /**
     * @return array{from: Transaction, to: Transaction}
     */
    public static function transfer(User $user, Account $from, Account $to, int $cents, string $date): array
    {
        return app(TransferService::class)->create($user, [
            'from_account_id' => $from->id,
            'to_account_id' => $to->id,
            'amount_cents' => $cents,
            'date' => $date,
        ]);
    }
}
