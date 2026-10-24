<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Jobs\MaterializeRecurringJob;
use Illuminate\Console\Command;

final class MaterializeRecurringCommand extends Command
{
    protected $signature = 'finance:materialize-recurring {--date= : Fecha de referencia (Y-m-d)}';

    protected $description = 'Crea los movimientos de las reglas recurrentes vencidas';

    public function handle(): int
    {
        $job = new MaterializeRecurringJob($this->dateOption());
        $this->laravel->call([$job, 'handle']);
        $this->info("Movimientos creados: {$job->created}");

        return self::SUCCESS;
    }

    private function dateOption(): ?string
    {
        $date = $this->option('date');

        return is_string($date) && $date !== '' ? $date : null;
    }
}
