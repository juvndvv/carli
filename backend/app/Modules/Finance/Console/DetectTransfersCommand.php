<?php

namespace App\Modules\Finance\Console;

use App\Modules\Finance\Domain\Enums\TransactionSource;
use App\Modules\Finance\Domain\Services\TransferDetector;
use App\Modules\Finance\Domain\Support\TransferCandidate;
use App\Modules\Finance\Domain\ValueObjects\Money;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Console\Command;

final class DetectTransfersCommand extends Command
{
    protected $signature = 'finance:detect-transfers {--dry-run : Muestra qué haría sin cambiar nada} {--user= : Solo este usuario (id)}';

    protected $description = 'Convierte en transferencias las parejas claras de gasto e ingreso importados entre cuentas propias';

    public function handle(TransferDetector $detector): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $user = $this->option('user');
        $userIds = Transaction::query()->withoutGlobalScopes()
            ->where('source', TransactionSource::Bank->value)
            ->when(is_string($user) && $user !== '', fn ($query) => $query->where('user_id', $user))
            ->distinct()
            ->pluck('user_id');

        $converted = 0;
        $suggested = 0;

        foreach ($userIds as $userId) {
            $result = $detector->detect((string) $userId, null, $dryRun);
            $converted += count($result['converted']);
            $suggested += count($result['suggested']);

            foreach ($result['converted'] as $candidate) {
                $this->line(($dryRun ? '[dry-run] Convertiría: ' : 'Convertida: ').$this->describe($candidate));
            }

            foreach ($result['suggested'] as $candidate) {
                $this->line('Sugerida: '.$this->describe($candidate));
            }
        }

        $this->info(($dryRun ? 'Transferencias que se convertirían: ' : 'Transferencias convertidas: ')."{$converted} · Sugerencias en Pendientes: {$suggested}");

        return self::SUCCESS;
    }

    private function describe(TransferCandidate $candidate): string
    {
        $signals = $candidate->signals === [] ? 'solo importe y fecha' : implode(', ', $candidate->signals);

        return sprintf(
            '%s %s → %s %s · %s · %s%s',
            $candidate->outgoing->date->toDateString(),
            $candidate->outgoing->account->name,
            $candidate->incoming->date->toDateString(),
            $candidate->incoming->account->name,
            Money::ofCents($candidate->outgoing->amount_cents)->abs()->format(),
            $signals,
            $candidate->unique ? '' : ' · varios candidatos',
        );
    }
}
