<?php

namespace App\Modules\Calendar\Console;

use App\Core\Modules\ModuleRegistry;
use App\Modules\Calendar\CalendarServiceProvider;
use App\Modules\Calendar\Domain\GoogleSync;
use App\Modules\Calendar\Models\GoogleAccount;
use Illuminate\Console\Command;

final class SyncGoogleCalendarsCommand extends Command
{
    protected $signature = 'calendar:sync';

    protected $description = 'Copia los eventos de las cuentas de Google conectadas';

    public function handle(GoogleSync $sync, ModuleRegistry $modules): int
    {
        $ok = 0;
        $failed = 0;

        GoogleAccount::query()->where('status', GoogleAccount::ACTIVE)->with('user')->each(function (GoogleAccount $account) use ($sync, $modules, &$ok, &$failed): void {
            if (! $modules->isEnabledFor($account->user, CalendarServiceProvider::MODULE)) {
                return;
            }

            $sync->run($account) ? $ok++ : $failed++;
        });

        $this->info("Cuentas sincronizadas: {$ok}, con error: {$failed}");

        return self::SUCCESS;
    }
}
