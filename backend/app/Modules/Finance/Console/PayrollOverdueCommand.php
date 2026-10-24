<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Jobs\CheckPayrollOverdue;
use Illuminate\Console\Command;

final class PayrollOverdueCommand extends Command
{
    protected $signature = 'finance:payroll-overdue {--date= : Fecha de referencia (Y-m-d)}';

    protected $description = 'Avisa si la nómina prevista no se ha registrado';

    public function handle(): int
    {
        $date = $this->option('date');
        $job = new CheckPayrollOverdue(is_string($date) && $date !== '' ? $date : null);
        $this->laravel->call([$job, 'handle']);
        $this->info("Notificaciones enviadas: {$job->sent}");

        return self::SUCCESS;
    }
}
