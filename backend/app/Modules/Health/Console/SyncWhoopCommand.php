<?php

namespace App\Modules\Health\Console;

use App\Core\Modules\ModuleRegistry;
use App\Modules\Health\Domain\HealthSettings;
use App\Modules\Health\Domain\WhoopSync;
use App\Modules\Health\Models\WhoopAccount;
use Illuminate\Console\Command;

final class SyncWhoopCommand extends Command
{
    protected $signature = 'health:whoop-sync';

    protected $description = 'Copia los ciclos, recuperaciones, sueños y entrenos de WHOOP';

    public function handle(WhoopSync $sync, ModuleRegistry $modules): int
    {
        $ok = 0;
        $failed = 0;

        WhoopAccount::query()->where('status', WhoopAccount::ACTIVE)->with('user')->each(function (WhoopAccount $account) use ($sync, $modules, &$ok, &$failed): void {
            if (! $modules->isEnabledFor($account->user, HealthSettings::MODULE)) {
                return;
            }

            $sync->run($account) ? $ok++ : $failed++;
        });

        $this->info("Cuentas de WHOOP sincronizadas: {$ok}, con error: {$failed}");

        return self::SUCCESS;
    }
}
