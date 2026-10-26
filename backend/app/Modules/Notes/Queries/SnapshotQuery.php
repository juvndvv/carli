<?php

namespace App\Modules\Notes\Queries;

use App\Models\User;
use App\Modules\Notes\Domain\Services\RestockService;
use App\Modules\Notes\Domain\Support\DatabaseTime;
use App\Modules\Notes\Http\Resources\FolderResource;
use App\Modules\Notes\Http\Resources\NoteResource;
use App\Modules\Notes\Http\Resources\ProductResource;
use App\Modules\Notes\Http\Resources\SectionResource;
use App\Modules\Notes\Models\Folder;
use App\Modules\Notes\Models\Note;
use App\Modules\Notes\Models\ShoppingProduct;
use App\Modules\Notes\Models\ShoppingSection;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;

final readonly class SnapshotQuery
{
    public const int TRASH_RETENTION_DAYS = 30;

    public function __construct(private RestockService $restock) {}

    /**
     * @return array{server_time: string, folders: array<mixed>, notes: array<mixed>, sections: array<mixed>, products: array<mixed>}
     */
    public function build(User $user, Request $request): array
    {
        $serverTime = CarbonImmutable::now();

        Note::query()->ownedBy($user)
            ->where('deleted_at', '<', DatabaseTime::format($serverTime->subDays(self::TRASH_RETENTION_DAYS)))
            ->delete();

        $this->restock->restockUser($user);

        return [
            'server_time' => $serverTime->toJSON(),
            'folders' => FolderResource::collection(Folder::query()->ownedBy($user)->orderBy('position')->orderBy('name')->get())->resolve($request),
            'notes' => NoteResource::collection(Note::query()->ownedBy($user)->with('items')->orderBy('sort')->orderBy('created_at')->get())->resolve($request),
            'sections' => SectionResource::collection(ShoppingSection::query()->ownedBy($user)->orderBy('position')->orderBy('name')->get())->resolve($request),
            'products' => ProductResource::collection(ShoppingProduct::query()->ownedBy($user)->orderBy('name_normalized')->get())->resolve($request),
        ];
    }
}
