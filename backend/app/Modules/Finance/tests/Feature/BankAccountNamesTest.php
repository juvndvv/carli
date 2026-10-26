<?php

use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Data\BankAccount;
use App\Modules\Finance\BankSync\Services\BankAccountNameService;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Http;

function revolutDetails(string $uid, ?string $details, string $name = 'Juan Daniel Forner Garriga', string $type = 'SVGS'): array
{
    return [
        'uid' => $uid,
        'account_id' => ['iban' => null, 'other' => ['identification' => 'abc', 'scheme_name' => 'OTHI']],
        'name' => $name,
        'details' => $details,
        'product' => null,
        'currency' => 'EUR',
        'cash_account_type' => $type,
    ];
}

function legacyLinkedAccount(object $test, string $uid, string $name): Account
{
    $account = F::account($test->user, ['name' => $name]);
    $account->forceFill(['bank_connection_id' => $test->connection->id, 'external_account_uid' => $uid, 'sync_from_date' => '2026-10-26'])->save();

    return $account;
}

describe('suggested names', function () {
    it('names accounts after the details or product the bank sends', function (array $data, string $expected) {
        expect(BankAccount::fromArray(['uid' => 'x', ...$data])->suggestedName($data['bank']))->toBe($expected);
    })->with([
        'BBVA online account' => [['bank' => 'BBVA', 'name' => 'JUAN DANIEL FORNER GARRIGA', 'details' => 'CUENTA ONLINE', 'product' => 'CUENTA ONLINE'], 'BBVA · Cuenta Online'],
        'Revolut main account' => [['bank' => 'Revolut', 'name' => 'Juan Daniel Forner Garriga'], 'Revolut · Principal'],
        'Revolut pocket' => [['bank' => 'Revolut', 'name' => 'Juan Daniel Forner Garriga', 'details' => 'Gastos'], 'Revolut · Gastos'],
        'product only' => [['bank' => 'ING', 'name' => 'Ana', 'product' => 'Cuenta NARANJA'], 'ING · Cuenta NARANJA'],
        'card without details' => [['bank' => 'BBVA', 'name' => 'JUAN', 'type' => 'CARD'], 'BBVA · Tarjeta'],
        'joint account' => [['bank' => 'Revolut', 'name' => 'JUAN DANIEL FORNER GARRIGA & OLEKSANDR ABRAMYAN KHAYDAROV'], 'Revolut · Compartida'],
    ]);

    it('keeps holder, details and product apart when reading the bank', function () {
        EB::configure();
        Http::fake([EB::BASE.'/accounts/p1/details' => Http::response(revolutDetails('p1', 'Ocio'))]);

        $account = app(BankDataProvider::class)->fetchAccount('p1');

        expect($account?->toArray())->toMatchArray(['name' => 'Juan Daniel Forner Garriga', 'details' => 'Ocio', 'product' => null, 'type' => 'SVGS']);
    });

    it('offers the suggested name when linking a new account', function () {
        $user = F::user();
        $connection = EB::connection($user, ['aspsp_name' => 'Revolut', 'accounts' => [['uid' => 'p1', 'identification_hash' => null, 'name' => 'Juan Daniel Forner Garriga', 'iban' => null, 'currency' => 'EUR', 'type' => 'SVGS', 'details' => 'Gastos', 'product' => null]]]);

        $this->actingAs($user)->getJson("/api/v1/finance/bank/connections/{$connection->id}/accounts")
            ->assertJsonPath('data.0.short_name', 'Gastos')
            ->assertJsonPath('data.0.suggested_name', 'Revolut · Gastos');
    });
});

describe('refreshing linked accounts', function () {
    beforeEach(function () {
        EB::configure();
        $this->user = F::user();
        $this->connection = EB::connection($this->user, ['aspsp_name' => 'Revolut', 'accounts' => [
            ['uid' => 'main', 'identification_hash' => 'h-main', 'name' => 'Juan Daniel Forner Garriga', 'iban' => 'ES75 •••• 7919', 'currency' => 'EUR', 'type' => 'CACC'],
            ['uid' => 'p1', 'identification_hash' => 'h-p1', 'name' => 'Juan Daniel Forner Garriga', 'iban' => null, 'currency' => 'EUR', 'type' => 'SVGS'],
            ['uid' => 'joint', 'identification_hash' => 'h-joint', 'name' => 'JUAN & OLEKSANDR', 'iban' => 'ES80 •••• 4156', 'currency' => 'EUR', 'type' => 'CACC'],
        ]]);
        $this->main = legacyLinkedAccount($this, 'main', 'Revolut Juan Daniel Forner Garriga');
        $this->pocket = legacyLinkedAccount($this, 'p1', 'Revolut Juan Daniel Forner Garriga');
        $this->joint = legacyLinkedAccount($this, 'joint', 'Compartida');
        Http::fake([
            EB::BASE.'/accounts/main/details' => Http::response(revolutDetails('main', null, type: 'CACC')),
            EB::BASE.'/accounts/p1/details' => Http::response(revolutDetails('p1', 'Gastos')),
            EB::BASE.'/accounts/joint/details' => Http::response(revolutDetails('joint', null, 'JUAN & OLEKSANDR', 'CACC')),
        ]);
    });

    it('only renames accounts that keep the old default name', function () {
        $this->artisan('finance:refresh-bank-account-names')
            ->expectsOutputToContain('Renombrada: Revolut Juan Daniel Forner Garriga → Revolut · Principal')
            ->expectsOutputToContain('Renombrada: Revolut Juan Daniel Forner Garriga → Revolut · Gastos')
            ->expectsOutputToContain('Cuentas renombradas: 2')
            ->assertSuccessful();

        expect([$this->main->refresh()->name, $this->pocket->refresh()->name, $this->joint->refresh()->name])
            ->toBe(['Revolut · Principal', 'Revolut · Gastos', 'Compartida'])
            ->and($this->connection->refresh()->bankAccount('p1'))->toMatchArray(['details' => 'Gastos', 'identification_hash' => 'h-p1']);
    });

    it('changes nothing on a dry run', function () {
        $this->artisan('finance:refresh-bank-account-names --dry-run')
            ->expectsOutputToContain('[dry-run] Renombraría: Revolut Juan Daniel Forner Garriga → Revolut · Gastos')
            ->expectsOutputToContain('Cuentas que se renombrarían: 2')
            ->assertSuccessful();

        expect($this->pocket->refresh()->name)->toBe('Revolut Juan Daniel Forner Garriga')
            ->and($this->connection->refresh()->bankAccount('p1'))->not->toHaveKey('details');
    });

    it('renames default names from the stored data after a renewal', function () {
        $this->connection->accounts = [...array_slice($this->connection->accounts ?? [], 0, 1), [...$this->connection->accounts[1], 'details' => 'Gastos']];
        $this->connection->save();

        app(BankAccountNameService::class)->renameDefaults($this->connection->refresh());

        expect([$this->main->refresh()->name, $this->pocket->refresh()->name])->toBe(['Revolut · Principal', 'Revolut · Gastos']);
    });
});
