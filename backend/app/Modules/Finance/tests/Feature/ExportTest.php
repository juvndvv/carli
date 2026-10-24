<?php

use App\Modules\Finance\Domain\Services\ContactService;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\tests\Support\FinanceFixtures as F;

it('exports the filtered transactions as a Spanish CSV', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $user = F::user();
    $account = F::account($user, ['name' => 'BBVA']);
    F::expense($user, $account, 123456, '2026-10-20', 'Supermercado', ['payee' => 'Mercadona', 'tags' => ['casa'], 'notes' => 'Compra; mensual']);
    F::income($user, $account, 250000, '2026-10-21', 'Nómina', ['payee' => 'ACME']);
    F::expense($user, $account, 500, '2026-09-01', 'Cafeterías', ['payee' => 'Café']);

    $response = $this->actingAs($user)->get('/api/v1/finance/transactions/export.csv?from=2026-10-01')
        ->assertOk()
        ->assertHeader('content-type', 'text/csv; charset=UTF-8');

    expect($response->headers->get('content-disposition'))->toContain('movimientos-2026-10-24.csv');

    $lines = array_values(array_filter(explode("\n", $response->streamedContent())));
    expect($lines)->toHaveCount(3)
        ->and($lines[0])->toBe("\u{FEFF}Fecha;Cuenta;Tipo;Categoría;Subcategoría;Comercio;Concepto;Importe;\"Parte propia\";Etiquetas;Estado;Notas")
        ->and($lines[1])->toBe('20/10/2026;BBVA;Gasto;Alimentación;Supermercado;Mercadona;;-1234,56;-1234,56;casa;Confirmado;"Compra; mensual"')
        ->and($lines[2])->toBe('21/10/2026;BBVA;Ingreso;Nómina;;ACME;;2500,00;;;Confirmado;');
});

it('downloads a full JSON backup of the module scoped to the user', function () {
    $this->travelTo(SpanishCalendar::date('2026-10-24')->setTime(12, 0));
    $user = F::user();
    $account = F::account($user, ['initial_balance_cents' => 1000]);
    $contact = app(ContactService::class)->create($user, 'Ana', null);
    $shared = F::expense($user, $account, 8000, '2026-10-20', 'Restaurantes', [
        'tags' => ['cena'],
        'shares' => ['mode' => 'equal', 'items' => [['contact_id' => $contact->id]]],
    ]);
    $deleted = F::expense($user, $account, 500, '2026-10-21');
    app(TransactionService::class)->delete($deleted);

    $intruder = F::user();
    F::expense($intruder, F::account($intruder), 999, '2026-10-20');

    $response = $this->actingAs($user)->get('/api/v1/finance/export.json')->assertOk();

    expect($response->headers->get('Content-Disposition'))->toContain('finanzas-backup-')
        ->and($response->json('format'))->toBe('personal-app/finance-backup')
        ->and($response->json('version'))->toBe(1);

    $tables = $response->json('tables');
    expect(array_keys($tables))->toContain('accounts', 'categories', 'transactions', 'transaction_tag', 'shared_expense_shares', 'periods', 'budgets', 'settings', 'goal_contributions')
        ->and(collect($tables['transactions'])->pluck('id')->all())->toEqualCanonicalizing([$shared->id, $deleted->id])
        ->and(collect($tables['transactions'])->firstWhere('id', $deleted->id)['deleted_at'])->not->toBeNull()
        ->and($tables['shared_expense_shares'])->toHaveCount(1)
        ->and($tables['shared_expense_shares'][0]['amount_cents'])->toBe(4000)
        ->and($tables['transaction_tag'])->toHaveCount(1)
        ->and(collect($tables['accounts'])->pluck('user_id')->unique()->all())->toBe([$user->id]);
});
