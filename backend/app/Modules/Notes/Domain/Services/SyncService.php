<?php

namespace App\Modules\Notes\Domain\Services;

use App\Models\User;
use App\Modules\Notes\Domain\Enums\OperationStatus;
use App\Modules\Notes\Domain\Support\DatabaseTime;
use App\Modules\Notes\Domain\Sync\Handlers\FolderDelete;
use App\Modules\Notes\Domain\Sync\Handlers\FolderUpsert;
use App\Modules\Notes\Domain\Sync\Handlers\ItemDelete;
use App\Modules\Notes\Domain\Sync\Handlers\ItemUpsert;
use App\Modules\Notes\Domain\Sync\Handlers\NotePurge;
use App\Modules\Notes\Domain\Sync\Handlers\NoteUpsert;
use App\Modules\Notes\Domain\Sync\Handlers\ProductDelete;
use App\Modules\Notes\Domain\Sync\Handlers\ProductUpsert;
use App\Modules\Notes\Domain\Sync\Handlers\SectionDelete;
use App\Modules\Notes\Domain\Sync\Handlers\SectionUpsert;
use App\Modules\Notes\Domain\Sync\Handlers\ShoppingFinish;
use App\Modules\Notes\Domain\Sync\Operation;
use App\Modules\Notes\Domain\Sync\OperationAlreadyProcessed;
use App\Modules\Notes\Domain\Sync\OperationHandler;
use App\Modules\Notes\Domain\Sync\OperationRejected;
use App\Modules\Notes\Domain\Sync\OperationResult;
use App\Modules\Notes\Domain\Sync\OperationStale;
use App\Modules\Notes\Models\SyncOperation;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Container\Container;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

final readonly class SyncService
{
    public const int RETENTION_DAYS = 30;

    private const array HANDLERS = [
        'folder.upsert' => FolderUpsert::class,
        'folder.delete' => FolderDelete::class,
        'note.upsert' => NoteUpsert::class,
        'note.purge' => NotePurge::class,
        'item.upsert' => ItemUpsert::class,
        'item.delete' => ItemDelete::class,
        'product.upsert' => ProductUpsert::class,
        'product.delete' => ProductDelete::class,
        'section.upsert' => SectionUpsert::class,
        'section.delete' => SectionDelete::class,
        'shopping.finish' => ShoppingFinish::class,
    ];

    public function __construct(private Container $container) {}

    /**
     * @param  list<Operation>  $operations
     * @return list<OperationResult>
     */
    public function apply(User $user, array $operations): array
    {
        SyncOperation::query()->ownedBy($user)
            ->where('processed_at', '<', DatabaseTime::format(CarbonImmutable::now()->subDays(self::RETENTION_DAYS)))
            ->delete();

        return array_map(fn (Operation $operation) => $this->applyOne($user, $operation), $operations);
    }

    private function applyOne(User $user, Operation $operation): OperationResult
    {
        $processed = SyncOperation::query()->withoutGlobalScope('user')->find($operation->id);

        if ($processed !== null) {
            return $processed->user_id === $user->id
                ? new OperationResult($operation->id, OperationStatus::Duplicate)
                : new OperationResult($operation->id, OperationStatus::Rejected, 'La operación no es válida.');
        }

        $handlerClass = self::HANDLERS[$operation->type] ?? null;

        if ($handlerClass === null) {
            return $this->finish($user, $operation, OperationStatus::Rejected, 'Tipo de operación desconocido.');
        }

        /** @var OperationHandler $handler */
        $handler = $this->container->make($handlerClass);

        try {
            DB::transaction(function () use ($handler, $user, $operation): void {
                $handler->handle($user, $operation);

                if (! $this->record($user, $operation, OperationStatus::Applied)) {
                    throw new OperationAlreadyProcessed;
                }
            });
        } catch (OperationAlreadyProcessed) {
            return new OperationResult($operation->id, OperationStatus::Duplicate);
        } catch (OperationStale) {
            return $this->finish($user, $operation, OperationStatus::Stale);
        } catch (OperationRejected $rejection) {
            return $this->finish($user, $operation, OperationStatus::Rejected, $rejection->getMessage());
        } catch (QueryException $exception) {
            report($exception);

            return $this->finish($user, $operation, OperationStatus::Rejected, 'No se ha podido aplicar el cambio.');
        }

        return new OperationResult($operation->id, OperationStatus::Applied);
    }

    private function finish(User $user, Operation $operation, OperationStatus $status, ?string $error = null): OperationResult
    {
        return $this->record($user, $operation, $status)
            ? new OperationResult($operation->id, $status, $error)
            : new OperationResult($operation->id, OperationStatus::Duplicate);
    }

    private function record(User $user, Operation $operation, OperationStatus $status): bool
    {
        return SyncOperation::query()->insertOrIgnore([
            'id' => $operation->id,
            'user_id' => $user->id,
            'type' => mb_substr($operation->type, 0, 64),
            'processed_at' => DatabaseTime::format(CarbonImmutable::now()),
            'status' => $status->value,
        ]) > 0;
    }
}
