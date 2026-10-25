<?php

namespace App\Core\Console;

use App\Core\Pending\SendPendingDigests;
use Illuminate\Console\Command;

final class PendingDigestCommand extends Command
{
    protected $signature = 'core:pending-digest {--date= : Fecha de referencia (Y-m-d)}';

    protected $description = 'Envía el resumen diario de pendientes a quien tenga alguno';

    public function handle(): int
    {
        $date = $this->option('date');
        $job = new SendPendingDigests(is_string($date) && $date !== '' ? $date : null);
        $this->laravel->call([$job, 'handle']);
        $this->info("Notificaciones enviadas: {$job->sent}");

        return self::SUCCESS;
    }
}
