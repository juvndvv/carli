<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Jobs\CheckBankConsentExpiry;
use Illuminate\Console\Command;

final class BankConsentExpiryCommand extends Command
{
    protected $signature = 'finance:bank-consent-expiry';

    protected $description = 'Avisa de conexiones bancarias a punto de caducar y marca las caducadas';

    public function handle(): int
    {
        $job = new CheckBankConsentExpiry;
        $this->laravel->call([$job, 'handle']);
        $this->info("Avisos enviados: {$job->sent}. Caducadas: {$job->expired}.");

        return self::SUCCESS;
    }
}
