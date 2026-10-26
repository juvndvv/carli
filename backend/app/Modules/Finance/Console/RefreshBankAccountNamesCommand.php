<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\BankSync\Exceptions\BankProviderException;
use App\Modules\Finance\BankSync\Services\BankAccountNameService;
use App\Modules\Finance\Models\BankConnection;
use Illuminate\Console\Command;

final class RefreshBankAccountNamesCommand extends Command
{
    protected $signature = 'finance:refresh-bank-account-names {--dry-run : Muestra qué cambiaría sin guardar nada}';

    protected $description = 'Relee los datos de las cuentas vinculadas y renombra las que siguen con el nombre por defecto antiguo';

    public function handle(BankAccountNameService $names): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $renamed = 0;

        foreach (BankConnection::query()->withoutGlobalScopes()->syncable()->get() as $connection) {
            try {
                $renames = $names->refresh($connection, $dryRun);
            } catch (BankProviderException $exception) {
                $this->warn("{$connection->aspsp_name}: {$exception->getMessage()}");

                continue;
            }

            foreach ($renames as $rename) {
                $this->line(($dryRun ? '[dry-run] Renombraría: ' : 'Renombrada: ')."{$rename['from']} → {$rename['to']}");
            }

            $renamed += count($renames);
        }

        $this->info(($dryRun ? 'Cuentas que se renombrarían: ' : 'Cuentas renombradas: ').$renamed);

        return self::SUCCESS;
    }
}
