<?php

namespace App\Modules\Finance;

use App\Core\Pending\PendingRegistry;
use App\Core\Search\ModuleSearcher;
use App\Modules\Finance\BankSync\Contracts\BankDataProvider;
use App\Modules\Finance\BankSync\Providers\EnableBankingProvider;
use App\Modules\Finance\BankSync\Services\BankConnectionService;
use App\Modules\Finance\BankSync\Services\BankSyncService;
use App\Modules\Finance\Console\BankConsentExpiryCommand;
use App\Modules\Finance\Console\BankSyncCommand;
use App\Modules\Finance\Console\DetectTransfersCommand;
use App\Modules\Finance\Console\MaterializeRecurringCommand;
use App\Modules\Finance\Console\PayrollOverdueCommand;
use App\Modules\Finance\Console\RefreshBankAccountNamesCommand;
use App\Modules\Finance\Console\UpcomingChargesCommand;
use App\Modules\Finance\Console\WeeklySummaryCommand;
use App\Modules\Finance\Domain\Services\AccountService;
use App\Modules\Finance\Domain\Services\BudgetService;
use App\Modules\Finance\Domain\Services\CategoryRuleService;
use App\Modules\Finance\Domain\Services\CategoryService;
use App\Modules\Finance\Domain\Services\ContactService;
use App\Modules\Finance\Domain\Services\DebtService;
use App\Modules\Finance\Domain\Services\DefaultCategories;
use App\Modules\Finance\Domain\Services\FinanceBootstrapper;
use App\Modules\Finance\Domain\Services\FinanceSettingsService;
use App\Modules\Finance\Domain\Services\GoalService;
use App\Modules\Finance\Domain\Services\PeriodService;
use App\Modules\Finance\Domain\Services\RecurringService;
use App\Modules\Finance\Domain\Services\ShareCalculator;
use App\Modules\Finance\Domain\Services\TagService;
use App\Modules\Finance\Domain\Services\TransactionService;
use App\Modules\Finance\Domain\Services\TransferService;
use App\Modules\Finance\Events\PayrollRegistered;
use App\Modules\Finance\Events\TransactionSaved;
use App\Modules\Finance\Http\Controllers\BankCallbackController;
use App\Modules\Finance\Http\Middleware\EnsureFinanceInitialized;
use App\Modules\Finance\Listeners\CheckBudgetThresholds;
use App\Modules\Finance\Listeners\CheckGoalMilestones;
use App\Modules\Finance\Listeners\OpenPeriodOnPayroll;
use App\Modules\Finance\Listeners\SyncDebtClosure;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use App\Modules\Finance\Models\Budget;
use App\Modules\Finance\Models\Category;
use App\Modules\Finance\Models\CategoryRule;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\Period;
use App\Modules\Finance\Models\RecurringRule;
use App\Modules\Finance\Models\SavingsGoal;
use App\Modules\Finance\Models\Tag;
use App\Modules\Finance\Models\Transaction;
use App\Modules\Finance\Pending\FinancePendingItems;
use App\Modules\Finance\Policies\OwnedByUserPolicy;
use App\Modules\Finance\Search\FinanceSearcher;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class FinanceServiceProvider extends ServiceProvider
{
    public const string TIMEZONE = 'Europe/Madrid';

    private const array SCOPED_SERVICES = [
        FinanceSettingsService::class,
        FinanceBootstrapper::class,
        DefaultCategories::class,
        PeriodService::class,
        TransactionService::class,
        TransferService::class,
        TagService::class,
        ShareCalculator::class,
        BudgetService::class,
        AccountService::class,
        CategoryService::class,
        RecurringService::class,
        GoalService::class,
        DebtService::class,
        ContactService::class,
        CategoryRuleService::class,
        BankSyncService::class,
        BankConnectionService::class,
    ];

    private const array OWNED_MODELS = [
        Account::class, BankConnection::class, Budget::class, Category::class, CategoryRule::class, Contact::class, Debt::class, Period::class,
        RecurringRule::class, SavingsGoal::class, Tag::class, Transaction::class,
    ];

    public static function manifestPath(): string
    {
        return __DIR__.'/module.php';
    }

    public function register(): void
    {
        foreach (self::SCOPED_SERVICES as $service) {
            $this->app->scoped($service);
        }

        $this->app->singleton(BankDataProvider::class, fn () => EnableBankingProvider::fromConfig((array) config('services.enable_banking', [])));

        if (interface_exists(ModuleSearcher::class)) {
            $this->app->tag([FinanceSearcher::class], ModuleSearcher::TAG);
        }

        $this->callAfterResolving(PendingRegistry::class, fn (PendingRegistry $pending) => $pending->register(FinancePendingItems::class));
    }

    public function boot(): void
    {
        $this->loadMigrationsFrom(__DIR__.'/database/migrations');

        Route::prefix('api/v1/finance')
            ->middleware(['api', 'auth:sanctum', 'module:finance', EnsureFinanceInitialized::class])
            ->group(__DIR__.'/routes/api.php');

        Route::prefix('api/v1/finance')
            ->middleware(['api', 'throttle:30,1'])
            ->get('bank/callback', BankCallbackController::class)
            ->name('finance.bank.callback');

        foreach (self::OWNED_MODELS as $model) {
            Gate::policy($model, OwnedByUserPolicy::class);
        }

        Event::listen(PayrollRegistered::class, OpenPeriodOnPayroll::class);
        Event::listen(TransactionSaved::class, CheckBudgetThresholds::class);
        Event::listen(TransactionSaved::class, CheckGoalMilestones::class);
        Event::listen(TransactionSaved::class, SyncDebtClosure::class);

        if ($this->app->runningInConsole()) {
            $this->commands([
                MaterializeRecurringCommand::class,
                UpcomingChargesCommand::class,
                PayrollOverdueCommand::class,
                WeeklySummaryCommand::class,
                BankSyncCommand::class,
                BankConsentExpiryCommand::class,
                DetectTransfersCommand::class,
                RefreshBankAccountNamesCommand::class,
            ]);
        }

        $this->callAfterResolving(Schedule::class, function (Schedule $schedule): void {
            $schedule->command('finance:materialize-recurring')->dailyAt('06:00')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
            $schedule->command('finance:upcoming-charges')->dailyAt('09:00')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
            $schedule->command('finance:payroll-overdue')->dailyAt('09:00')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
            $schedule->command('finance:bank-sync')->cron('0 7,13,19 * * *')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
            $schedule->command('finance:bank-consent-expiry')->dailyAt('09:00')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
            $schedule->command('finance:weekly-summary')->weeklyOn(1, '09:00')->timezone(self::TIMEZONE)->withoutOverlapping()->onOneServer();
        });
    }
}
