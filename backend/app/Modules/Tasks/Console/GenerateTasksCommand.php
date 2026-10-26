<?php

namespace App\Modules\Tasks\Console;

use App\Modules\Tasks\Jobs\GenerateTasksJob;
use Illuminate\Console\Command;

final class GenerateTasksCommand extends Command
{
    protected $signature = 'tasks:generate {--date= : Fecha de referencia (Y-m-d)}';

    protected $description = 'Crea las tareas de las plantillas que tocan (y pone al día las perdidas)';

    public function handle(): int
    {
        $date = $this->option('date');
        $job = new GenerateTasksJob(is_string($date) && $date !== '' ? $date : null);
        $this->laravel->call([$job, 'handle']);
        $this->info("Tareas creadas: {$job->created}");

        return self::SUCCESS;
    }
}
