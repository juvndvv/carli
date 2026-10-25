<?php

use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Support\MerchantText;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\CategoryRule;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

function importedExpense(object $test, int $cents, string $date, ?string $payee, ?string $description = null, ?Account $account = null): Transaction
{
    return app(TransactionService::class)->create($test->user, [
        'account_id' => ($account ?? $test->account)->id,
        'kind' => 'expense',
        'amount_cents' => -abs($cents),
        'date' => $date,
        'payee' => $payee,
        'description' => $description,
    ], source: TransactionSource::Bank);
}

beforeEach(function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $this->user = F::user();
    $this->account = F::account($this->user);
    F::income($this->user, $this->account, 250000, '2026-09-28');
    $this->actingAs($this->user);
    $this->supermarket = F::category($this->user, 'Supermercado');
});

it('normalizes merchant text', function () {
    expect(MerchantText::normalize('Mercadoña  Valencia 1234 ** XXXX'))->toBe('MERCADONA VALENCIA')
        ->and(MerchantText::of(null, 'Compra tarjeta BAR PEPE'))->toBe('COMPRA TARJETA BAR PEPE')
        ->and(MerchantText::contains('COMPRA MERCADONA VALENCIA', 'MERCADONA'))->toBeTrue()
        ->and(MerchantText::contains('MERCADONAS', 'MERCADONA'))->toBeFalse();
});

describe('rules crud', function () {
    it('creates, lists, updates and deletes rules', function () {
        $id = $this->postJson('/api/v1/finance/category-rules', ['pattern' => ' mercadona ', 'category_id' => $this->supermarket->id])
            ->assertCreated()
            ->assertJsonPath('data.pattern', 'MERCADONA')
            ->assertJsonPath('data.kind', 'expense')
            ->assertJsonPath('data.category.name', 'Supermercado')
            ->json('data.id');

        $this->postJson('/api/v1/finance/category-rules', ['pattern' => 'MERCADONA', 'category_id' => F::category($this->user, 'Restaurantes')->id])
            ->assertCreated()
            ->assertJsonPath('data.id', $id);

        $this->getJson('/api/v1/finance/category-rules')->assertOk()->assertJsonCount(1, 'data');

        $this->patchJson("/api/v1/finance/category-rules/{$id}", ['pattern' => 'Lidl'])
            ->assertOk()
            ->assertJsonPath('data.pattern', 'LIDL');

        $this->deleteJson("/api/v1/finance/category-rules/{$id}")->assertNoContent();
        expect(CategoryRule::query()->count())->toBe(0);
    });

    it('rejects patterns without letters and foreign rules', function () {
        $this->postJson('/api/v1/finance/category-rules', ['pattern' => '1234', 'category_id' => $this->supermarket->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('pattern');

        $other = F::user();
        $foreign = new CategoryRule(['pattern' => 'LIDL', 'kind' => 'expense', 'category_id' => F::category($other, 'Supermercado')->id]);
        $foreign->user_id = $other->id;
        $foreign->save();

        $this->getJson("/api/v1/finance/category-rules/{$foreign->id}")->assertNotFound();
    });
});

describe('apply to similar', function () {
    it('counts the uncategorized transactions from the same merchant', function () {
        $target = importedExpense($this, 1234, '2026-10-20', 'MERCADONA');
        importedExpense($this, 999, '2026-10-21', 'Mercadona');
        importedExpense($this, 500, '2026-10-22', 'BAR PEPE');
        F::expense($this->user, $this->account, 700, '2026-10-22', 'Supermercado', ['payee' => 'MERCADONA']);

        $this->getJson("/api/v1/finance/transactions/{$target->id}/similar")
            ->assertOk()
            ->assertJsonPath('data.count', 1)
            ->assertJsonPath('data.pattern', 'MERCADONA');
    });

    it('matches by a custom pattern inside payee or description', function () {
        $target = importedExpense($this, 1234, '2026-10-20', null, 'COMPRA TARJ MERCADONA VALENCIA');
        importedExpense($this, 999, '2026-10-21', null, 'COMPRA TARJ MERCADONA ALBORAYA');

        $this->getJson("/api/v1/finance/transactions/{$target->id}/similar")->assertJsonPath('data.count', 0);
        $this->getJson("/api/v1/finance/transactions/{$target->id}/similar?pattern=mercadona")->assertJsonPath('data.count', 1);
    });

    it('categorizes the transaction and its similar ones and remembers the rule', function () {
        $target = importedExpense($this, 1234, '2026-10-20', 'MERCADONA');
        $similar = importedExpense($this, 999, '2026-10-21', 'MERCADONA');
        $unrelated = importedExpense($this, 500, '2026-10-22', 'BAR PEPE');

        $this->postJson("/api/v1/finance/transactions/{$target->id}/categorize-similar", [
            'category_id' => $this->supermarket->id,
            'remember' => true,
        ])->assertOk()
            ->assertJsonPath('data.updated', 2)
            ->assertJsonPath('data.transaction.category_id', $this->supermarket->id)
            ->assertJsonPath('data.transaction.uncategorized', false)
            ->assertJsonPath('data.rule.pattern', 'MERCADONA');

        expect($similar->refresh()->category_id)->toBe($this->supermarket->id)
            ->and($unrelated->refresh()->category_id)->toBeNull()
            ->and(CategoryRule::query()->where('pattern', 'MERCADONA')->exists())->toBeTrue();

        $this->getJson('/api/v1/pending/summary')->assertJsonPath('data.total', 1);
    });

    it('does not remember a rule unless asked', function () {
        $target = importedExpense($this, 1234, '2026-10-20', 'MERCADONA');

        $this->postJson("/api/v1/finance/transactions/{$target->id}/categorize-similar", ['category_id' => $this->supermarket->id])
            ->assertOk()
            ->assertJsonPath('data.updated', 1)
            ->assertJsonPath('data.rule', null);

        expect(CategoryRule::query()->exists())->toBeFalse();
    });

    it('rejects a category of the wrong kind', function () {
        $target = importedExpense($this, 1234, '2026-10-20', 'MERCADONA');

        $this->postJson("/api/v1/finance/transactions/{$target->id}/categorize-similar", ['category_id' => F::category($this->user, 'Nómina')->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('category_id');
    });
});
