<?php

use App\Modules\Finance\Http\Controllers\AccountController;
use App\Modules\Finance\Http\Controllers\BackupController;
use App\Modules\Finance\Http\Controllers\BankConnectionController;
use App\Modules\Finance\Http\Controllers\BudgetController;
use App\Modules\Finance\Http\Controllers\CategoryController;
use App\Modules\Finance\Http\Controllers\CategoryRuleController;
use App\Modules\Finance\Http\Controllers\ContactController;
use App\Modules\Finance\Http\Controllers\DashboardController;
use App\Modules\Finance\Http\Controllers\DebtController;
use App\Modules\Finance\Http\Controllers\GoalController;
use App\Modules\Finance\Http\Controllers\PayeeController;
use App\Modules\Finance\Http\Controllers\PeriodController;
use App\Modules\Finance\Http\Controllers\RecurringRuleController;
use App\Modules\Finance\Http\Controllers\SettingsController;
use App\Modules\Finance\Http\Controllers\SimilarTransactionsController;
use App\Modules\Finance\Http\Controllers\SummaryController;
use App\Modules\Finance\Http\Controllers\TagController;
use App\Modules\Finance\Http\Controllers\TransactionController;
use App\Modules\Finance\Http\Controllers\TransferController;
use App\Modules\Finance\Http\Controllers\TransferDetectionController;
use App\Modules\Finance\Http\Controllers\WidgetController;
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
    'bank_connection' => $uuid,
    'category_rule' => $uuid,
])->name('finance.')->group(function (): void {
    Route::get('summary', SummaryController::class)->name('summary');
    Route::get('dashboard', DashboardController::class)->name('dashboard');
    Route::get('widget', WidgetController::class)->name('widget');
    Route::get('export.json', BackupController::class)->name('backup');

    Route::get('periods', [PeriodController::class, 'index'])->name('periods.index');
    Route::post('periods', [PeriodController::class, 'store'])->name('periods.store');
    Route::patch('periods/{period}', [PeriodController::class, 'update'])->name('periods.update');

    Route::post('accounts/{account}/reconcile', [AccountController::class, 'reconcile'])->name('accounts.reconcile');
    Route::apiResource('accounts', AccountController::class);

    Route::patch('transactions/bulk', [TransactionController::class, 'bulk'])->name('transactions.bulk');
    Route::get('transactions/export.csv', [TransactionController::class, 'export'])->name('transactions.export');
    Route::get('transactions/{transaction}/similar', [SimilarTransactionsController::class, 'count'])->name('transactions.similar');
    Route::post('transactions/{transaction}/categorize-similar', [SimilarTransactionsController::class, 'categorize'])->name('transactions.categorize-similar');
    Route::post('transactions/{transaction}/convert-to-transfer', [TransferDetectionController::class, 'link'])->name('transactions.convert-to-transfer');
    Route::post('transactions/{transaction}/undo-transfer', [TransferDetectionController::class, 'undo'])->name('transactions.undo-transfer');
    Route::post('transactions/{transaction}/restore', [TransactionController::class, 'restore'])->withTrashed()->name('transactions.restore');
    Route::apiResource('transactions', TransactionController::class);

    Route::post('transfers', [TransferController::class, 'store'])->name('transfers.store');
    Route::post('transfers/suggestions/confirm', [TransferDetectionController::class, 'confirm'])->name('transfers.suggestions.confirm');
    Route::post('transfers/suggestions/dismiss', [TransferDetectionController::class, 'dismiss'])->name('transfers.suggestions.dismiss');
    Route::get('payees/suggest', [PayeeController::class, 'suggest'])->name('payees.suggest');

    Route::get('categories/suggest', [PayeeController::class, 'suggestCategory'])->name('categories.suggest');
    Route::apiResource('categories', CategoryController::class);
    Route::apiResource('category-rules', CategoryRuleController::class);
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

    Route::prefix('bank')->name('bank.')->group(function (): void {
        Route::get('aspsps', [BankConnectionController::class, 'aspsps'])->name('aspsps');
        Route::get('connections', [BankConnectionController::class, 'index'])->name('connections.index');
        Route::post('connections', [BankConnectionController::class, 'store'])->middleware('throttle:20,1')->name('connections.store');
        Route::get('connections/{bank_connection}', [BankConnectionController::class, 'show'])->name('connections.show');
        Route::get('connections/{bank_connection}/accounts', [BankConnectionController::class, 'accounts'])->name('connections.accounts.index');
        Route::post('connections/{bank_connection}/accounts', [BankConnectionController::class, 'link'])->name('connections.accounts.link');
        Route::post('connections/{bank_connection}/sync', [BankConnectionController::class, 'sync'])->middleware('throttle:10,1')->name('connections.sync');
        Route::post('connections/{bank_connection}/renew', [BankConnectionController::class, 'renew'])->middleware('throttle:20,1')->name('connections.renew');
        Route::delete('connections/{bank_connection}', [BankConnectionController::class, 'destroy'])->name('connections.destroy');
    });

    Route::get('settings', [SettingsController::class, 'show'])->name('settings.show');
    Route::put('settings', [SettingsController::class, 'update'])->name('settings.update');
    Route::patch('settings', [SettingsController::class, 'update'])->name('settings.patch');
});
