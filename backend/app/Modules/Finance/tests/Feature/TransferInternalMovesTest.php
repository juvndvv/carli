<?php

use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Services\TransferDetector;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\EnableBankingFake as EB;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;

function revolutAccount(object $test, BankConnection $connection, string $uid, string $name): Account
{
    $account = F::account($test->user, ['name' => $name]);
    $account->forceFill(['bank_connection_id' => $connection->id, 'external_account_uid' => $uid, 'sync_from_date' => '2026-10-01'])->save();

    return $account;
}

/**
 * @param  array<string, mixed>  $raw
 */
function revolutMovement(Account $account, int $cents, string $date, string $description, array $raw = ['creditor' => [], 'debtor' => [], 'bank_transaction_code' => ['code' => 'TRANSFER']]): Transaction
{
    $transaction = new Transaction;
    $transaction->user_id = $account->user_id;
    $transaction->account_id = $account->id;
    $transaction->kind = $cents < 0 ? 'expense' : 'income';
    $transaction->amount_cents = $cents;
    $transaction->date = SpanishCalendar::date($date);
    $transaction->description = $description;
    $transaction->status = TransactionStatus::Cleared;
    $transaction->source = TransactionSource::Bank;
    $transaction->external_id = (string) Str::uuid();
    $transaction->raw = $raw;
    $transaction->save();

    return $transaction;
}

function detectRevolut(object $test, bool $dryRun = false): array
{
    return app(TransferDetector::class)->detect($test->user, null, $dryRun);
}

beforeEach(function () {
    Notification::fake();
    $this->travelTo(SpanishCalendar::date('2026-10-26')->setTime(12, 0));
    $this->user = F::user();
    $this->user->forceFill(['name' => 'Demo'])->save();
    $this->connection = EB::connection($this->user, ['aspsp_name' => 'Revolut', 'accounts' => [
        ['uid' => 'main', 'identification_hash' => null, 'name' => 'Juan Daniel Forner Garriga', 'iban' => 'ES75 •••• 7919', 'currency' => 'EUR', 'type' => 'CACC', 'details' => null, 'product' => null],
        ['uid' => 'gastos', 'identification_hash' => null, 'name' => 'Juan Daniel Forner Garriga', 'iban' => null, 'currency' => 'EUR', 'type' => 'SVGS', 'details' => 'Gastos', 'product' => null],
    ]]);
    $this->main = revolutAccount($this, $this->connection, 'main', 'Revolut · Principal');
    $this->gastos = revolutAccount($this, $this->connection, 'gastos', 'Revolut Juan Daniel Forner Garriga');
    $this->actingAs($this->user);
});

describe('internal moves between accounts of the same bank', function () {
    it('converts a move to a pocket named in the concept', function () {
        $out = revolutMovement($this->main, -20000, '2026-10-03', 'To EUR Gastos');
        revolutMovement($this->gastos, 20000, '2026-10-03', 'From EUR');

        $result = detectRevolut($this);

        expect($result['converted'])->toHaveCount(1)
            ->and($result['converted'][0]->signals)->toBe(['internal'])
            ->and($out->refresh()->transfer_source?->value)->toBe('auto');
    });

    it('does not treat a payment to someone else as internal', function () {
        revolutMovement($this->main, -20000, '2026-10-03', 'To EUR Gastos', ['creditor' => ['name' => 'Ana Pérez']]);
        revolutMovement($this->gastos, 20000, '2026-10-03', 'From EUR');

        $result = detectRevolut($this);

        expect($result['converted'])->toBe([])->and($result['suggested'][0]->signals)->toBe([]);
    });

    it('needs both accounts in the same bank connection', function () {
        $other = EB::connection($this->user, ['aspsp_name' => 'Revolut', 'accounts' => [['uid' => 'x', 'identification_hash' => null, 'name' => 'X', 'iban' => null, 'currency' => 'EUR', 'type' => 'SVGS', 'details' => 'Gastos', 'product' => null]]]);
        $elsewhere = revolutAccount($this, $other, 'x', 'Revolut · Gastos');
        revolutMovement($this->main, -20000, '2026-10-03', 'To EUR Gastos');
        revolutMovement($elsewhere, 20000, '2026-10-03', 'From EUR');

        expect(detectRevolut($this)['converted'])->toBe([]);
    });
});

describe('moves to an account the bank does not expose', function () {
    beforeEach(function () {
        $this->remunerada = F::account($this->user, ['name' => 'Revolut · Cuenta Remunerada', 'type' => 'savings']);
    });

    it('links moves to and from the manual account with the same name', function () {
        $out = revolutMovement($this->main, -31102, '2026-10-05', 'To Cuenta Remunerada');
        $in = revolutMovement($this->main, 30000, '2026-10-23', 'From Cuenta Remunerada');

        $result = detectRevolut($this);

        expect($result['linked'])->toHaveCount(2)
            ->and($out->refresh()->kind->value)->toBe('transfer')
            ->and($out->transfer_source?->value)->toBe('auto')
            ->and($in->refresh()->kind->value)->toBe('transfer')
            ->and($this->remunerada->balanceCents())->toBe(31102 - 30000)
            ->and(Transaction::query()->where('account_id', $this->remunerada->id)->pluck('source')->map->value->all())->toBe(['manual', 'manual']);
    });

    it('reports without linking on a dry run and is idempotent', function () {
        $out = revolutMovement($this->main, -31102, '2026-10-05', 'To Cuenta Remunerada');

        expect(detectRevolut($this, dryRun: true)['linked'])->toHaveCount(1)
            ->and($out->refresh()->kind->value)->toBe('expense')
            ->and(detectRevolut($this)['linked'])->toHaveCount(1)
            ->and(detectRevolut($this)['linked'])->toBe([]);
    });

    it('does nothing without a matching manual account', function () {
        revolutMovement($this->main, -5000, '2026-10-05', 'To Hucha Viaje');

        expect(detectRevolut($this)['linked'])->toBe([]);
    });

    it('does nothing when several manual accounts match', function () {
        F::account($this->user, ['name' => 'Cuenta Remunerada']);
        revolutMovement($this->main, -31102, '2026-10-05', 'To Cuenta Remunerada');

        expect(detectRevolut($this)['linked'])->toBe([]);
    });

    it('does nothing for movements with an external counterparty or the wrong direction', function () {
        revolutMovement($this->main, -31102, '2026-10-05', 'To Cuenta Remunerada', ['creditor' => ['name' => 'Ana Pérez']]);
        revolutMovement($this->main, 1000, '2026-10-05', 'To Cuenta Remunerada');
        revolutMovement($this->main, -2000, '2026-10-05', 'To Cuenta Remunerada', ['creditor_account' => ['iban' => 'ES0000000000000000001234']]);

        expect(detectRevolut($this)['linked'])->toBe([]);
    });

    it('does not link again after the user undoes it', function () {
        $out = revolutMovement($this->main, -31102, '2026-10-05', 'To Cuenta Remunerada');
        detectRevolut($this);

        $this->postJson("/api/v1/finance/transactions/{$out->id}/undo-transfer")->assertOk();

        expect($out->refresh()->kind->value)->toBe('expense')
            ->and(Transaction::query()->where('account_id', $this->remunerada->id)->count())->toBe(0)
            ->and(detectRevolut($this)['linked'])->toBe([]);
    });

    it('prefers a pair with another imported account over the manual link', function () {
        $pocket = F::account($this->user, ['name' => 'Gastos']);
        revolutMovement($this->main, -20000, '2026-10-03', 'To EUR Gastos');
        revolutMovement($this->gastos, 20000, '2026-10-03', 'From EUR');

        $result = detectRevolut($this);

        expect($result['converted'])->toHaveCount(1)->and($result['linked'])->toBe([])
            ->and(Transaction::query()->where('account_id', $pocket->id)->count())->toBe(0);
    });
});
