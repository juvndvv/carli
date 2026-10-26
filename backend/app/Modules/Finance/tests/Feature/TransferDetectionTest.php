<?php

use App\Models\User;
use App\Modules\Finance\BankSync\Services\BankSyncService;
use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Services\TransferDetector;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Models\TransferExclusion;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;

const BBVA_IBAN = 'ES3901820000000000005055';

const REVOLUT_IBAN = 'ES7515830000000000007919';

function linkedBankAccount(User $user, string $bank, string $uid, string $iban, string $name): Account
{
    $connection = EB::connection($user, [
        'aspsp_name' => $bank,
        'accounts' => [['uid' => $uid, 'identification_hash' => "hash-{$uid}", 'name' => $name, 'iban' => substr($iban, 0, 4).' •••• '.substr($iban, -4), 'currency' => 'EUR', 'type' => 'CACC']],
    ]);
    $account = F::account($user, ['name' => $name]);
    $account->forceFill([
        'bank_connection_id' => $connection->id,
        'external_account_uid' => $uid,
        'external_account_hash' => "hash-{$uid}",
        'sync_from_date' => '2026-10-01',
    ])->save();

    return $account;
}

/**
 * @param  array<string, mixed>  $raw
 */
function importedMovement(Account $account, int $cents, string $date, ?string $payee = null, array $raw = [], ?string $description = null): Transaction
{
    $transaction = new Transaction;
    $transaction->user_id = $account->user_id;
    $transaction->account_id = $account->id;
    $transaction->kind = $cents < 0 ? 'expense' : 'income';
    $transaction->amount_cents = $cents;
    $transaction->date = SpanishCalendar::date($date);
    $transaction->payee = $payee;
    $transaction->description = $description;
    $transaction->status = TransactionStatus::Cleared;
    $transaction->source = TransactionSource::Bank;
    $transaction->external_id = (string) Str::uuid();
    $transaction->raw = $raw;
    $transaction->save();

    return $transaction;
}

function detectTransfers(User $user, bool $dryRun = false): array
{
    return app(TransferDetector::class)->detect($user, null, $dryRun);
}

/**
 * @return list<array<string, mixed>>
 */
function pendingOfType(object $test, string $type): array
{
    return $test->getJson("/api/v1/pending?module=finance&type={$type}")->assertOk()->json('data');
}

beforeEach(function () {
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->user->forceFill(['name' => 'Juan Daniel Forner Garriga'])->save();
    $this->bbva = linkedBankAccount($this->user, 'BBVA', 'bbva-uid', BBVA_IBAN, 'BBVA Cuenta');
    $this->revolut = linkedBankAccount($this->user, 'Revolut', 'revolut-uid', REVOLUT_IBAN, 'Revolut Personal');
    $this->myinvestor = F::account($this->user, ['name' => 'MyInvestor', 'type' => 'savings']);
    $this->actingAs($this->user);
});

describe('clear matches', function () {
    it('converts a pair whose counterparty IBAN is the other account', function () {
        $out = importedMovement($this->bbva, -50000, '2026-10-05', 'ACME', ['creditor_account' => ['iban' => REVOLUT_IBAN]]);
        $in = importedMovement($this->revolut, 50000, '2026-10-03', 'Alguien');

        $result = detectTransfers($this->user);
        $out->refresh();
        $in->refresh();

        expect($result['converted'])->toHaveCount(1)
            ->and($result['converted'][0]->signals)->toBe(['iban'])
            ->and($out->kind->value)->toBe('transfer')
            ->and($in->kind->value)->toBe('transfer')
            ->and($out->transfer_group_id)->not->toBeNull()->toBe($in->transfer_group_id)
            ->and($out->category_id)->toBeNull()
            ->and($out->transfer_source?->value)->toBe('auto')
            ->and($in->transfer_detected_at)->not->toBeNull()
            ->and([$out->amount_cents, $out->date->toDateString(), $out->account_id])->toBe([-50000, '2026-10-05', $this->bbva->id]);
    });

    it('converts a pair whose counterparty is the account holder, tolerating order and separators', function () {
        importedMovement($this->revolut, -30000, '2026-10-23', 'Juan Daniel Forner Garriga', ['creditor' => ['name' => 'Juan Daniel Forner Garriga']]);
        importedMovement($this->bbva, 30000, '2026-10-23', 'FORNER GARRIGA JUAN', ['debtor' => ['name' => 'FORNER;GARRIGA;JUAN']]);

        expect(detectTransfers($this->user)['converted'][0]->signals)->toBe(['holder']);
    });

    it('recognizes the holder from the own side of the bank data when the profile name differs', function () {
        $this->user->forceFill(['name' => 'Demo'])->save();
        importedMovement($this->bbva, -30000, '2026-10-06', 'JUAN DANIEL FORNER GARRIGA', [
            'debtor' => ['name' => 'JUAN DANIEL FORNER GARRIGA'],
            'creditor' => ['name' => 'JUAN DANIEL FORNER GARRIGA'],
        ]);
        importedMovement($this->revolut, 30000, '2026-10-07', 'Ingreso');

        expect(detectTransfers($this->user)['converted'][0]->signals)->toBe(['holder']);
    });

    it('converts a top-up that names the other bank', function () {
        importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        importedMovement($this->revolut, 5000, '2026-10-10', 'Top-up');

        expect(detectTransfers($this->user)['converted'][0]->signals)->toBe(['concept']);
    });

    it('accepts a partially masked account number from the bank', function () {
        importedMovement($this->bbva, 30000, '2026-10-23', 'Alguien', ['debtor_account' => ['other' => ['scheme_name' => 'BBAN', 'identification' => 'ES******************7919']]]);
        importedMovement($this->revolut, -30000, '2026-10-23', 'Otro');

        expect(detectTransfers($this->user)['converted'][0]->signals)->toBe(['iban']);
    });
});

describe('doubtful matches', function () {
    it('suggests a pair that only shares amount and date, without listing it as uncategorized', function () {
        $out = importedMovement($this->bbva, -12000, '2026-10-10', 'ACME');
        $in = importedMovement($this->revolut, 12000, '2026-10-11', 'Fulano');
        $other = importedMovement($this->bbva, -999, '2026-10-12', 'Mercadona');

        expect(detectTransfers($this->user)['converted'])->toBe([])
            ->and($out->refresh()->kind->value)->toBe('expense');

        $suggestions = pendingOfType($this, 'transfer_suggestion');
        expect($suggestions)->toHaveCount(1)
            ->and($suggestions[0]['title'])->toBe('¿Es una transferencia entre BBVA y Revolut?')
            ->and($suggestions[0]['amount_cents'])->toBe(12000)
            ->and($suggestions[0]['meta']['outgoing_transaction_id'])->toBe($out->id)
            ->and($suggestions[0]['meta']['incoming_transaction_id'])->toBe($in->id)
            ->and(collect(pendingOfType($this, 'uncategorized_transaction'))->pluck('id')->all())->toBe([$other->id]);

        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.by_module', [
            ['module' => 'finance', 'module_name' => 'Finanzas', 'type' => 'transfer_suggestion', 'count' => 1],
            ['module' => 'finance', 'module_name' => 'Finanzas', 'type' => 'uncategorized_transaction', 'count' => 1],
        ]);
    });

    it('only suggests when several candidates share amount and dates, picking the closest', function () {
        $out = importedMovement($this->bbva, -10000, '2026-10-10', 'ACME', ['creditor_account' => ['iban' => REVOLUT_IBAN]]);
        importedMovement($this->revolut, 10000, '2026-10-08', 'Uno');
        $closest = importedMovement($this->revolut, 10000, '2026-10-10', 'Dos');

        $result = detectTransfers($this->user);

        expect($result['converted'])->toBe([])
            ->and($result['suggested'])->toHaveCount(1)
            ->and($result['suggested'][0]->unique)->toBeFalse()
            ->and($result['suggested'][0]->incoming->id)->toBe($closest->id)
            ->and($out->refresh()->kind->value)->toBe('expense');
    });

    it('suggests instead of converting a clear pair the user already categorized', function () {
        importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut')
            ->forceFill(['category_id' => F::category($this->user, 'Supermercado')->id])->save();
        importedMovement($this->revolut, 5000, '2026-10-10', 'Top-up');

        $result = detectTransfers($this->user);

        expect($result['converted'])->toBe([])->and($result['suggested'][0]->isClear())->toBeTrue();
    });

    it('confirms a suggestion into a transfer', function () {
        $out = importedMovement($this->bbva, -12000, '2026-10-10', 'ACME');
        $in = importedMovement($this->revolut, 12000, '2026-10-11', 'Fulano');

        $this->postJson('/api/v1/finance/transfers/suggestions/confirm', [
            'outgoing_transaction_id' => $out->id,
            'incoming_transaction_id' => $in->id,
        ])->assertCreated()
            ->assertJsonPath('data.from.kind', 'transfer')
            ->assertJsonPath('data.from.transfer_source', 'confirmed')
            ->assertJsonPath('data.from.transfer_undoable', true)
            ->assertJsonPath('data.to.transfer_account_id', $this->bbva->id);

        expect(pendingOfType($this, 'transfer_suggestion'))->toBe([]);
    });

    it('remembers a dismissed suggestion', function () {
        $out = importedMovement($this->bbva, -12000, '2026-10-10', 'ACME');
        $in = importedMovement($this->revolut, 12000, '2026-10-11', 'Fulano');

        $this->postJson('/api/v1/finance/transfers/suggestions/dismiss', [
            'outgoing_transaction_id' => $out->id,
            'incoming_transaction_id' => $in->id,
        ])->assertOk();

        expect(pendingOfType($this, 'transfer_suggestion'))->toBe([])
            ->and(pendingOfType($this, 'uncategorized_transaction'))->toHaveCount(2)
            ->and(detectTransfers($this->user)['suggested'])->toBe([]);
    });

    it('rejects confirming movements that do not match', function () {
        $out = importedMovement($this->bbva, -12000, '2026-10-10', 'ACME');
        $in = importedMovement($this->revolut, 12500, '2026-10-11', 'Fulano');

        $this->postJson('/api/v1/finance/transfers/suggestions/confirm', [
            'outgoing_transaction_id' => $out->id,
            'incoming_transaction_id' => $in->id,
        ])->assertUnprocessable()->assertJsonValidationErrors('incoming_transaction_id');
    });
});

describe('no match', function () {
    it('ignores pairs more than three days apart', function () {
        importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        importedMovement($this->revolut, 5000, '2026-10-14', 'Top-up');

        expect(detectTransfers($this->user))->toBe(['converted' => [], 'suggested' => [], 'linked' => []]);
    });

    it('accepts pairs exactly three days apart', function () {
        importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        importedMovement($this->revolut, 5000, '2026-10-13', 'Top-up');

        expect(detectTransfers($this->user)['converted'])->toHaveCount(1);
    });

    it('ignores different amounts', function () {
        importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        importedMovement($this->revolut, 5001, '2026-10-10', 'Top-up');

        expect(detectTransfers($this->user))->toBe(['converted' => [], 'suggested' => [], 'linked' => []]);
    });

    it('ignores movements in the same account', function () {
        importedMovement($this->revolut, -30000, '2026-10-23', 'To Cuenta Remunerada');
        importedMovement($this->revolut, 30000, '2026-10-23', 'From Cuenta Remunerada');

        expect(detectTransfers($this->user))->toBe(['converted' => [], 'suggested' => [], 'linked' => []]);
    });

    it('ignores manual movements, deleted rows and existing transfers', function () {
        F::expense($this->user, $this->bbva, 7000, '2026-10-10');
        importedMovement($this->revolut, 7000, '2026-10-10', 'Top-up');
        importedMovement($this->bbva, -8000, '2026-10-10', 'Personal Revolut')->delete();
        importedMovement($this->revolut, 8000, '2026-10-10', 'Top-up');
        F::transfer($this->user, $this->bbva, $this->revolut, 9000, '2026-10-10');

        expect(detectTransfers($this->user))->toBe(['converted' => [], 'suggested' => [], 'linked' => []]);
    });
});

describe('undo', function () {
    it('restores both movements without category and never matches them again', function () {
        $out = importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        $in = importedMovement($this->revolut, 5000, '2026-10-10', 'Top-up');
        detectTransfers($this->user);

        $this->postJson("/api/v1/finance/transactions/{$in->id}/undo-transfer")
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.transfer_group_id', null);

        $out->refresh();
        $in->refresh();
        expect([$out->kind->value, $in->kind->value])->toBe(['expense', 'income'])
            ->and([$out->category_id, $out->transfer_source, $in->transfer_detected_at])->toBe([null, null, null])
            ->and(TransferExclusion::query()->where('outgoing_transaction_id', $out->id)->where('incoming_transaction_id', $in->id)->exists())->toBeTrue()
            ->and(detectTransfers($this->user))->toBe(['converted' => [], 'suggested' => [], 'linked' => []])
            ->and(pendingOfType($this, 'uncategorized_transaction'))->toHaveCount(2);
    });

    it('refuses to undo transfers the user created by hand', function () {
        $legs = F::transfer($this->user, $this->bbva, $this->myinvestor, 9000, '2026-10-10');

        $this->postJson("/api/v1/finance/transactions/{$legs['from']->id}/undo-transfer")->assertUnprocessable();
    });
});

describe('idempotency', function () {
    it('converts each pair once', function () {
        importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        $in = importedMovement($this->revolut, 5000, '2026-10-10', 'Top-up');

        detectTransfers($this->user);
        $group = $in->refresh()->transfer_group_id;

        expect(detectTransfers($this->user))->toBe(['converted' => [], 'suggested' => [], 'linked' => []])
            ->and($in->refresh()->transfer_group_id)->toBe($group);
    });

    it('reports without changing anything on a dry run, then converts from the command', function () {
        $out = importedMovement($this->bbva, -5000, '2026-10-10', 'Personal Revolut');
        importedMovement($this->revolut, 5000, '2026-10-10', 'Top-up');
        importedMovement($this->bbva, -12000, '2026-10-10', 'ACME');
        importedMovement($this->revolut, 12000, '2026-10-11', 'Fulano');

        $this->artisan('finance:detect-transfers --dry-run')
            ->expectsOutputToContain('[dry-run] Convertiría: 2026-10-10 BBVA Cuenta → 2026-10-10 Revolut Personal · 50,00 € · concept')
            ->expectsOutputToContain('Transferencias que se convertirían: 1 · Enlazadas con cuentas manuales: 0 · Sugerencias en Pendientes: 1')
            ->assertSuccessful();
        expect($out->refresh()->kind->value)->toBe('expense');

        $this->artisan('finance:detect-transfers')->expectsOutputToContain('Transferencias convertidas: 1')->assertSuccessful();
        expect($out->refresh()->kind->value)->toBe('transfer');
    });
});

describe('bank sync', function () {
    it('detects transfers at the end of a sync and records how many', function () {
        EB::configure();
        $connection = $this->bbva->bankConnection;
        importedMovement($this->revolut, 50000, '2026-10-22', 'Juan Daniel Forner Garriga', ['debtor' => ['name' => 'JUAN DANIEL FORNER GARRIGA']]);
        EB::fakeAccountData([
            EB::transaction('500.00', 'DBIT', '2026-10-23', 'ref-1', 'Personal Revolut', ['creditor_account' => ['iban' => REVOLUT_IBAN]]),
        ], '1000.00', 'bbva-uid');

        $result = app(BankSyncService::class)->sync($connection->refresh());

        expect($result)->toBe(['imported' => 1, 'accounts' => 1, 'transfers' => 1])
            ->and($connection->refresh()->last_sync_transfers)->toBe(1)
            ->and(Transaction::query()->where('account_id', $this->bbva->id)->sole()->kind->value)->toBe('transfer');

        $this->getJson("/api/v1/finance/bank/connections/{$connection->id}")->assertJsonPath('data.last_sync_transfers', 1);
    });

    it('only auto-converts recent pairs during a sync', function () {
        importedMovement($this->bbva, -5000, '2026-08-10', 'Personal Revolut');
        importedMovement($this->revolut, 5000, '2026-08-10', 'Top-up');

        $result = app(TransferDetector::class)->detect($this->user, SpanishCalendar::today()->subDays(TransferDetector::SYNC_WINDOW_DAYS));

        expect($result['converted'])->toBe([])->and($result['suggested'])->toHaveCount(1);
    });
});

describe('transfer to an account that is not connected', function () {
    it('turns an import into one leg and creates the other in a manual account', function () {
        $imported = importedMovement($this->bbva, -100000, '2026-10-06', 'JUAN DANIEL FORNER GARRIGA', [], 'TRANSFERENCIA REALIZADA');

        $response = $this->postJson("/api/v1/finance/transactions/{$imported->id}/convert-to-transfer", ['account_id' => $this->myinvestor->id])
            ->assertCreated()
            ->assertJsonPath('data.from.id', $imported->id)
            ->assertJsonPath('data.from.transfer_source', 'linked')
            ->assertJsonPath('data.to.account_id', $this->myinvestor->id)
            ->assertJsonPath('data.to.amount_cents', 100000)
            ->assertJsonPath('data.to.date', '2026-10-06')
            ->assertJsonPath('data.to.source', 'manual');

        expect($response->json('data.to.transfer_group_id'))->toBe($response->json('data.from.transfer_group_id'))
            ->and($this->myinvestor->balanceCents())->toBe(100000)
            ->and($imported->refresh()->kind->value)->toBe('transfer');
    });

    it('undoes by deleting the created leg', function () {
        $imported = importedMovement($this->bbva, 20000, '2026-10-06', 'Rescate');
        $created = $this->postJson("/api/v1/finance/transactions/{$imported->id}/convert-to-transfer", ['account_id' => $this->myinvestor->id])
            ->assertCreated()
            ->json('data.from.id');

        $this->postJson("/api/v1/finance/transactions/{$created}/undo-transfer")->assertOk()->assertJsonPath('data.0.kind', 'income');

        expect(Transaction::query()->withTrashed()->whereKey($created)->exists())->toBeFalse()
            ->and($imported->refresh()->kind->value)->toBe('income')
            ->and(TransferExclusion::query()->count())->toBe(0);
    });

    it('only links imported movements to manual accounts', function () {
        $imported = importedMovement($this->bbva, -100000, '2026-10-06', 'X');
        $manual = F::expense($this->user, $this->bbva, 500, '2026-10-06');

        $this->postJson("/api/v1/finance/transactions/{$imported->id}/convert-to-transfer", ['account_id' => $this->revolut->id])
            ->assertUnprocessable()->assertJsonValidationErrors('account_id');
        $this->postJson("/api/v1/finance/transactions/{$imported->id}/convert-to-transfer", ['account_id' => $this->bbva->id])
            ->assertUnprocessable()->assertJsonValidationErrors('account_id');
        $this->postJson("/api/v1/finance/transactions/{$manual->id}/convert-to-transfer", ['account_id' => $this->myinvestor->id])
            ->assertUnprocessable()->assertJsonValidationErrors('transaction');
    });
});

describe('immutability', function () {
    it('keeps amount and date of converted bank legs locked on both legs', function () {
        $imported = importedMovement($this->bbva, -100000, '2026-10-06', 'X');
        $created = $this->postJson("/api/v1/finance/transactions/{$imported->id}/convert-to-transfer", ['account_id' => $this->myinvestor->id])
            ->json('data.to.id');

        $this->patchJson("/api/v1/finance/transactions/{$imported->id}", ['amount_cents' => -1])->assertUnprocessable();
        $this->patchJson("/api/v1/finance/transactions/{$imported->id}", ['kind' => 'expense'])->assertUnprocessable();
        $this->patchJson("/api/v1/finance/transactions/{$created}", ['amount_cents' => 5])->assertUnprocessable()->assertJsonValidationErrors('amount_cents');
        $this->patchJson("/api/v1/finance/transactions/{$created}", ['date' => '2026-10-07'])->assertUnprocessable()->assertJsonValidationErrors('date');
        $this->patchJson("/api/v1/finance/transactions/{$created}", ['notes' => 'Aportación'])->assertOk();

        expect($imported->refresh()->amount_cents)->toBe(-100000);
    });
});

describe('reporting', function () {
    it('drops converted movements from income, spending and the payroll period', function () {
        $income = importedMovement($this->bbva, 250000, '2026-10-01', 'Juan Daniel Forner Garriga');
        $this->patchJson("/api/v1/finance/transactions/{$income->id}", ['category_id' => F::category($this->user, 'Nómina')->id])->assertOk();
        expect(app(PeriodService::class)->current($this->user)->opening_transaction_id)->toBe($income->id);

        $out = importedMovement($this->revolut, -250000, '2026-10-02', 'Ana');

        $this->postJson('/api/v1/finance/transfers/suggestions/confirm', [
            'outgoing_transaction_id' => $out->id,
            'incoming_transaction_id' => $income->id,
        ])->assertCreated();

        expect(app(PeriodService::class)->current($this->user)->opening_transaction_id)->not->toBe($income->id);

        $this->getJson('/api/v1/finance/transactions?kind=income&from=2026-09-01&to=2026-10-31')->assertJsonCount(0, 'data');
    });
});
