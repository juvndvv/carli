<?php

namespace App\Modules\Finance\database\seeders;

use App\Models\User;
use App\Modules\Finance\Domain\Services\AccountService;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\ContactService;
use App\Modules\Finance\Domain\Services\DebtService;
use App\Modules\Finance\Domain\Services\FinanceBootstrapper;
use App\Modules\Finance\Domain\Services\GoalService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Services\TransferService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\Transaction;
use Carbon\CarbonImmutable;
use Illuminate\Database\Seeder;

class FinanceDemoSeeder extends Seeder
{
    public const string DEMO_EMAIL = 'demo@example.com';

    /** @var array<string, string> */
    private array $categories = [];

    private int $seed = 20261024;

    public function __construct(
        private readonly FinanceBootstrapper $bootstrapper,
        private readonly AccountService $accounts,
        private readonly TransactionService $transactions,
        private readonly TransferService $transfers,
        private readonly RecurringService $recurring,
        private readonly PeriodService $periods,
        private readonly BudgetService $budgets,
        private readonly GoalService $goals,
        private readonly DebtService $debts,
        private readonly ContactService $contacts,
    ) {}

    public function run(): void
    {
        $user = User::query()->where('email', self::DEMO_EMAIL)->first();

        if ($user === null || Account::query()->ownedBy($user)->exists()) {
            return;
        }

        $this->bootstrapper->ensure($user);
        $this->categories = Category::query()->ownedBy($user)->pluck('id', 'name')->all();

        $today = SpanishCalendar::today();
        $start = $today->subMonthsNoOverflow(3)->setDay(28);

        $checking = $this->accounts->create($user, [
            'name' => 'Cuenta nómina', 'type' => 'checking', 'initial_balance_cents' => 185000,
            'initial_balance_date' => $start->subDay()->toDateString(), 'color' => 'c1', 'icon' => 'landmark',
        ]);
        $savings = $this->accounts->create($user, [
            'name' => 'Cuenta ahorro', 'type' => 'savings', 'initial_balance_cents' => 600000,
            'initial_balance_date' => $start->subDay()->toDateString(), 'color' => 'c2', 'icon' => 'piggy-bank',
        ]);
        $card = $this->accounts->create($user, [
            'name' => 'Visa', 'type' => 'credit_card', 'initial_balance_cents' => 0, 'credit_limit_cents' => 300000,
            'statement_day' => 25, 'payment_day' => 5, 'initial_balance_date' => $start->subDay()->toDateString(), 'color' => 'c3', 'icon' => 'credit-card',
        ]);
        $cash = $this->accounts->create($user, [
            'name' => 'Efectivo', 'type' => 'cash', 'initial_balance_cents' => 12000,
            'initial_balance_date' => $start->subDay()->toDateString(), 'color' => 'c4', 'icon' => 'wallet',
        ]);

        $ana = $this->contacts->create($user, 'Ana', null);
        $luis = $this->contacts->create($user, 'Luis', 'Compañero de piso');

        $rules = [
            $this->rule($user, $checking, 'Nómina', 'income', 245000, 'ACME S.L.', 'monthly', $start, 'auto', false),
            $this->rule($user, $checking, 'Alquiler', 'expense', 75000, 'Inmobiliaria Sol', 'monthly', $start->addMonthNoOverflow()->startOfMonth(), 'auto', false),
            $this->rule($user, $checking, 'Internet y móvil', 'expense', 4500, 'Digi', 'monthly', $start->setDay(15), 'auto', false),
            $this->rule($user, $card, 'Streaming', 'expense', 1399, 'Netflix', 'monthly', $start->setDay(12), 'auto', true),
            $this->rule($user, $card, 'Streaming', 'expense', 1099, 'Spotify', 'monthly', $start->setDay(20), 'auto', true),
            $this->rule($user, $checking, 'Gimnasio', 'expense', 3990, 'Basic-Fit', 'monthly', $start->setDay(5)->addMonthNoOverflow(), 'auto', true),
            $this->rule($user, $card, 'Software', 'expense', 999, 'iCloud+', 'monthly', $start->setDay(3)->addMonthNoOverflow(), 'auto', true),
            $this->rule($user, $checking, 'Luz', 'expense', 6200, 'Iberdrola', 'monthly', $start->setDay(22), 'confirm', false),
        ];

        $loan = $this->debts->create($user, [
            'name' => 'Préstamo coche',
            'direction' => 'i_owe',
            'principal_cents' => 900000,
            'start_date' => $start->subMonthsNoOverflow(2)->toDateString(),
            'notes' => 'Financiación del concesionario',
            'plan' => [
                'account_id' => $checking->id,
                'installment_cents' => 25000,
                'installments_count' => 36,
                'first_payment_date' => $start->subMonthsNoOverflow(2)->setDay(5)->toDateString(),
                'payment_day' => 5,
                'category_id' => $this->categories['Transporte'] ?? null,
                'mode' => 'auto',
            ],
        ]);

        foreach ($rules as $ruleId) {
            $this->recurring->materialize($ruleId, $today);
        }

        $electricity = RecurringRule::query()->ownedBy($user)->findOrFail(end($rules));
        $pending = Transaction::query()->ownedBy($user)->where('recurring_rule_id', $electricity->id)->where('status', 'pending')->count();
        for ($confirmed = 1; $confirmed < $pending; $confirmed++) {
            $this->recurring->confirm($electricity, ['amount_cents' => 5800 + $confirmed * 350]);
        }
        if ($loan->recurring_rule_id !== null) {
            $this->recurring->materialize($loan->recurring_rule_id, $today);
        }

        $this->dailyLife($user, $checking, $card, $cash, $start, $today);
        $this->monthlyTransfers($user, $checking, $savings, $card, $cash, $start, $today);
        $this->shared($user, $checking, $card, $ana, $luis, $today);

        $this->debts->create($user, [
            'name' => 'Entradas del concierto',
            'direction' => 'owed_to_me',
            'contact_id' => $luis->id,
            'principal_cents' => 6000,
            'start_date' => $today->subDays(10)->toDateString(),
            'due_date' => $today->addDays(2)->toDateString(),
        ]);

        $trip = $this->goals->create($user, [
            'name' => 'Viaje a Japón',
            'target_cents' => 300000,
            'target_date' => $today->addMonthsNoOverflow(8)->endOfMonth()->toDateString(),
            'icon' => 'plane',
            'color' => 'c5',
        ]);
        foreach ([2, 1, 0] as $monthsAgo) {
            $this->goals->contribute($trip, ['amount_cents' => 25000, 'date' => $today->subMonthsNoOverflow($monthsAgo)->startOfMonth()->addDays(1)->toDateString(), 'note' => 'Aportación mensual']);
        }
        $this->goals->create($user, [
            'name' => 'Fondo de emergencia',
            'target_cents' => 1000000,
            'account_id' => $savings->id,
            'icon' => 'shield',
            'color' => 'c6',
        ]);

        $this->budgetsForAllPeriods($user);
    }

    private function rule(User $user, Account $account, string $category, string $kind, int $cents, string $payee, string $frequency, CarbonImmutable $startDate, string $mode, bool $subscription): string
    {
        return $this->recurring->create($user, [
            'account_id' => $account->id,
            'category_id' => $this->categories[$category] ?? null,
            'kind' => $kind,
            'amount_cents' => $cents,
            'payee' => $payee,
            'frequency' => $frequency,
            'start_date' => $startDate->toDateString(),
            'mode' => $mode,
            'is_subscription' => $subscription,
        ])->id;
    }

    private function dailyLife(User $user, Account $checking, Account $card, Account $cash, CarbonImmutable $start, CarbonImmutable $today): void
    {
        $patterns = [
            ['Supermercado', ['Mercadona', 'Lidl', 'Carrefour'], 3500, 8500, 4, ['casa']],
            ['Restaurantes', ['La Tagliatella', 'Foster\'s Hollywood', 'Bar Manolo'], 1800, 4200, 9, []],
            ['Cafeterías', ['Starbucks', 'Café Central'], 250, 650, 4, []],
            ['Combustible', ['Repsol', 'Cepsa'], 4500, 6000, 15, []],
            ['Transporte público', ['Metro de Madrid', 'Renfe'], 150, 1210, 8, []],
            ['Farmacia', ['Farmacia Lda. García'], 600, 2400, 25, []],
            ['Ropa', ['Zara', 'Decathlon', 'Uniqlo'], 1990, 6990, 25, []],
            ['Cine y espectáculos', ['Cines Yelmo', 'Teatro Real'], 900, 3500, 16, []],
            ['Otros', ['Amazon'], 1200, 4500, 14, []],
            ['Libros', ['Casa del Libro'], 1490, 2890, 40, []],
        ];

        $day = $start;
        while ($day->lessThanOrEqualTo($today)) {
            foreach ($patterns as [$category, $payees, $min, $max, $every, $tags]) {
                if ($this->random(1, $every) !== 1) {
                    continue;
                }

                $account = match (true) {
                    in_array($category, ['Cafeterías', 'Transporte público'], true) && $this->random(1, 3) === 1 => $cash,
                    in_array($category, ['Ropa', 'Otros', 'Restaurantes', 'Libros'], true) => $card,
                    default => $this->random(1, 2) === 1 ? $card : $checking,
                };

                $this->transactions->create($user, [
                    'account_id' => $account->id,
                    'kind' => 'expense',
                    'amount_cents' => -$this->random($min, $max),
                    'date' => $day->toDateString(),
                    'category_id' => $this->categories[$category] ?? null,
                    'payee' => $payees[$this->random(0, count($payees) - 1)],
                    'tags' => $tags,
                ]);
            }

            $day = $day->addDay();
        }

        $this->transactions->create($user, [
            'account_id' => $checking->id,
            'kind' => 'income',
            'amount_cents' => 4580,
            'date' => $start->addDays(20)->toDateString(),
            'category_id' => $this->categories['Reembolsos'] ?? null,
            'payee' => 'Hacienda',
            'description' => 'Devolución IRPF',
        ]);

        $this->transactions->create($user, [
            'account_id' => $card->id,
            'kind' => 'expense',
            'amount_cents' => -34560,
            'date' => $start->addDays(12)->toDateString(),
            'category_id' => $this->categories['Viajes'] ?? null,
            'payee' => 'Iberia',
            'description' => 'Vuelos escapada',
            'tags' => ['vacaciones-2026'],
        ]);

        $this->transactions->create($user, [
            'account_id' => $checking->id,
            'kind' => 'expense',
            'amount_cents' => -11000,
            'date' => $start->addMonthNoOverflow()->addDays(10)->toDateString(),
            'payee' => 'Hipercor',
            'description' => 'Compra grande',
            'splits' => [
                ['category_id' => $this->categories['Supermercado'], 'amount_cents' => -7500],
                ['category_id' => $this->categories['Regalos'], 'amount_cents' => -3500],
            ],
        ]);
    }

    private function monthlyTransfers(User $user, Account $checking, Account $savings, Account $card, Account $cash, CarbonImmutable $start, CarbonImmutable $today): void
    {
        $month = $start;
        while ($month->lessThanOrEqualTo($today)) {
            $saving = $month->addDay();
            if ($saving->lessThanOrEqualTo($today)) {
                $this->transfers->create($user, [
                    'from_account_id' => $checking->id,
                    'to_account_id' => $savings->id,
                    'amount_cents' => 20000,
                    'date' => $saving->toDateString(),
                    'description' => 'Ahorro mensual',
                ]);
                $this->transfers->create($user, [
                    'from_account_id' => $checking->id,
                    'to_account_id' => $cash->id,
                    'amount_cents' => 6000,
                    'date' => $saving->addDays(3)->min($today)->toDateString(),
                    'description' => 'Retirada de cajero',
                ]);
            }

            $cardPayment = $month->addMonthNoOverflow()->setDay(5);
            if ($cardPayment->lessThanOrEqualTo($today)) {
                $debt = -(int) Transaction::query()->ownedBy($user)->where('account_id', $card->id)->where('date', '<', $cardPayment->toDateString())->sum('amount_cents');
                if ($debt > 0) {
                    $this->transfers->create($user, [
                        'from_account_id' => $checking->id,
                        'to_account_id' => $card->id,
                        'amount_cents' => $debt,
                        'date' => $cardPayment->toDateString(),
                        'description' => 'Liquidación tarjeta',
                    ]);
                }
            }

            $month = $month->addMonthNoOverflow();
        }
    }

    private function shared(User $user, Account $checking, Account $card, Contact $ana, Contact $luis, CarbonImmutable $today): void
    {
        $this->transactions->create($user, [
            'account_id' => $card->id,
            'kind' => 'expense',
            'amount_cents' => -8000,
            'date' => $today->subDays(3)->toDateString(),
            'category_id' => $this->categories['Restaurantes'] ?? null,
            'payee' => 'Sushi Kaito',
            'description' => 'Cena con Ana',
            'shares' => ['mode' => 'percentage', 'items' => [['contact_id' => $ana->id, 'percentage' => '50']]],
        ]);

        $this->transactions->create($user, [
            'account_id' => $checking->id,
            'kind' => 'expense',
            'amount_cents' => -13560,
            'date' => $today->subDays(25)->toDateString(),
            'category_id' => $this->categories['Supermercado'] ?? null,
            'payee' => 'Mercadona',
            'description' => 'Compra del piso',
            'tags' => ['casa'],
            'shares' => ['mode' => 'equal', 'items' => [['contact_id' => $luis->id]]],
        ]);
        $this->contacts->settle($luis, ['account_id' => $checking->id, 'date' => $today->subDays(20)->toDateString()]);

        $this->transactions->create($user, [
            'account_id' => $checking->id,
            'kind' => 'expense',
            'amount_cents' => -4590,
            'date' => $today->subDays(6)->toDateString(),
            'category_id' => $this->categories['Luz'] ?? null,
            'payee' => 'Naturgy',
            'description' => 'Gas del piso',
            'shares' => ['mode' => 'equal', 'items' => [['contact_id' => $luis->id]]],
        ]);
    }

    private function budgetsForAllPeriods(User $user): void
    {
        $amounts = [
            'Hogar' => 110000,
            'Alimentación' => 45000,
            'Transporte' => 40000,
            'Ocio' => 15000,
            'Suscripciones' => 8000,
            'Ropa' => 10000,
            'Salud' => 5000,
        ];

        foreach ($this->periods->all($user) as $period) {
            $items = [];
            foreach ($amounts as $name => $cents) {
                if (isset($this->categories[$name])) {
                    $items[] = ['category_id' => $this->categories[$name], 'amount_cents' => $cents, 'rollover' => $name === 'Ocio'];
                }
            }
            $this->budgets->upsert($period, $items);
        }
    }

    private function random(int $min, int $max): int
    {
        $this->seed = ($this->seed * 1103515245 + 12345) % 2147483648;

        return $min + $this->seed % ($max - $min + 1);
    }
}
