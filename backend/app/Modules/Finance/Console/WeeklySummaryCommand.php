<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Jobs\SendWeeklySummaries;
use Illuminate\Console\Command;

final class WeeklySummaryCommand extends Command
{
    protected $signature = 'finance:weekly-summary {--date= : Fecha de referencia (Y-m-d)}';

    protected $description = 'Envía el resumen semanal de finanzas';

    public function handle(): int
    {
        $date = $this->option('date');
        $job = new SendWeeklySummaries(is_string($date) && $date !== '' ? $date : null);
        $this->laravel->call([$job, 'handle']);
        $this->info("Notificaciones enviadas: {$job->sent}");

        return self::SUCCESS;
    }
}
