<?php

use App\Modules\Finance\Http\Controllers\AccountController;
use App\Modules\Finance\Http\Controllers\BackupController;
use App\Modules\Finance\Http\Controllers\BudgetController;
use App\Modules\Finance\Http\Controllers\CategoryController;
use App\Modules\Finance\Http\Controllers\ContactController;
use App\Modules\Finance\Http\Controllers\DashboardController;
use App\Modules\Finance\Http\Controllers\DebtController;
use App\Modules\Finance\Http\Controllers\GoalController;
use App\Modules\Finance\Http\Controllers\PayeeController;
use App\Modules\Finance\Http\Controllers\PeriodController;
use App\Modules\Finance\Http\Controllers\RecurringRuleController;
use App\Modules\Finance\Http\Controllers\SettingsController;
use App\Modules\Finance\Http\Controllers\SummaryController;
use App\Modules\Finance\Http\Controllers\TagController;
use App\Modules\Finance\Http\Controllers\TransactionController;
use App\Modules\Finance\Http\Controllers\TransferController;
use Illuminate\Support\Facades\Route;

$uuid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

Route::where([
    'account' => $uuid,
    'transaction' => $uuid,
    'category' => $uuid,
    'tag' => $uuid,
    'period' => $uuid,
    'recurring_rule' => $uuid,
    'goal' => $uuid,
    'contribution' => $uuid,
    'contact' => $uuid,
    'debt' => $uuid,
])->name('finance.')->group(function (): void {
    Route::get('summary', SummaryController::class)->name('summary');
    Route::get('dashboard', DashboardController::class)->name('dashboard');
    Route::get('export.json', BackupController::class)->name('backup');

    Route::get('periods', [PeriodController::class, 'index'])->name('periods.index');
    Route::post('periods', [PeriodController::class, 'store'])->name('periods.store');
    Route::patch('periods/{period}', [PeriodController::class, 'update'])->name('periods.update');

    Route::post('accounts/{account}/reconcile', [AccountController::class, 'reconcile'])->name('accounts.reconcile');
    Route::apiResource('accounts', AccountController::class);

    Route::patch('transactions/bulk', [TransactionController::class, 'bulk'])->name('transactions.bulk');
    Route::get('transactions/export.csv', [TransactionController::class, 'export'])->name('transactions.export');
    Route::post('transactions/{transaction}/restore', [TransactionController::class, 'restore'])->withTrashed()->name('transactions.restore');
    Route::apiResource('transactions', TransactionController::class);

    Route::post('transfers', [TransferController::class, 'store'])->name('transfers.store');
    Route::get('payees/suggest', [PayeeController::class, 'suggest'])->name('payees.suggest');

    Route::get('categories/suggest', [PayeeController::class, 'suggestCategory'])->name('categories.suggest');
    Route::apiResource('categories', CategoryController::class);
    Route::post('tags/{tag}/merge', [TagController::class, 'merge'])->name('tags.merge');
    Route::apiResource('tags', TagController::class);

    Route::get('budgets', [BudgetController::class, 'index'])->name('budgets.index');
    Route::put('budgets', [BudgetController::class, 'update'])->name('budgets.update');
    Route::post('budgets/copy', [BudgetController::class, 'copy'])->name('budgets.copy');

    Route::post('recurring-rules/{recurring_rule}/confirm', [RecurringRuleController::class, 'confirm'])->name('recurring-rules.confirm');
    Route::apiResource('recurring-rules', RecurringRuleController::class);

    Route::get('goals/{goal}/contributions', [GoalController::class, 'contributions'])->name('goals.contributions.index');
    Route::post('goals/{goal}/contributions', [GoalController::class, 'storeContribution'])->name('goals.contributions.store');
    Route::delete('goals/{goal}/contributions/{contribution}', [GoalController::class, 'destroyContribution'])->name('goals.contributions.destroy');
    Route::apiResource('goals', GoalController::class);

    Route::post('contacts/{contact}/settle', [ContactController::class, 'settle'])->name('contacts.settle');
    Route::apiResource('contacts', ContactController::class);

    Route::get('debts/{debt}/payments', [DebtController::class, 'payments'])->name('debts.payments.index');
    Route::post('debts/{debt}/payments', [DebtController::class, 'storePayment'])->name('debts.payments.store');
    Route::apiResource('debts', DebtController::class);

    Route::get('settings', [SettingsController::class, 'show'])->name('settings.show');
    Route::put('settings', [SettingsController::class, 'update'])->name('settings.update');
    Route::patch('settings', [SettingsController::class, 'update'])->name('settings.patch');
});
