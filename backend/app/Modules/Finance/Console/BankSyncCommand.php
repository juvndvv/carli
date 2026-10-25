<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Jobs\SyncBankConnection;
use App\Modules\Finance\Models\BankConnection;
use Illuminate\Console\Command;

final class BankSyncCommand extends Command
{
    protected $signature = 'finance:bank-sync';

    protected $description = 'Encola una sincronización por cada conexión bancaria activa';

    public function handle(): int
    {
        $ids = BankConnection::query()->withoutGlobalScopes()->syncable()->pluck('id');

        foreach ($ids as $id) {
            SyncBankConnection::dispatch((string) $id);
        }

        $this->info("Sincronizaciones encoladas: {$ids->count()}");

        return self::SUCCESS;
    }
}
