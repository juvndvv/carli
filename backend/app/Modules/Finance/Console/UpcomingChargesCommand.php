<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Jobs\SendUpcomingChargeReminders;
use Illuminate\Console\Command;

final class UpcomingChargesCommand extends Command
{
    protected $signature = 'finance:upcoming-charges {--date= : Fecha de referencia (Y-m-d)}';

    protected $description = 'Envía avisos de cargos recurrentes próximos, pendientes de confirmar y deudas';

    public function handle(): int
    {
        $date = $this->option('date');
        $job = new SendUpcomingChargeReminders(is_string($date) && $date !== '' ? $date : null);
        $this->laravel->call([$job, 'handle']);
        $this->info("Notificaciones enviadas: {$job->sent}");

        return self::SUCCESS;
    }
}
