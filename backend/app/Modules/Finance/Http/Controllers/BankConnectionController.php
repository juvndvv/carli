<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\BankSync\Data\BankAccount;
use App\Modules\Finance\BankSync\Data\PsuContext;
use App\Modules\Finance\BankSync\Services\BankConnectionService;
use App\Modules\Finance\Domain\Enums\BankConnectionStatus;
use App\Modules\Finance\Http\Requests\BankAspspsRequest;
use App\Modules\Finance\Http\Requests\LinkBankAccountsRequest;
use App\Modules\Finance\Http\Requests\RenewBankConnectionRequest;
use App\Modules\Finance\Http\Requests\StoreBankConnectionRequest;
use App\Modules\Finance\Http\Resources\BankConnectionResource;
use App\Modules\Finance\Jobs\SyncBankConnection;
use App\Modules\Finance\Models\Account;
use App\Modules\Finance\Models\BankConnection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Validation\ValidationException;

final class BankConnectionController extends FinanceController
{
    public function __construct(private readonly BankConnectionService $connections) {}

    public function aspsps(BankAspspsRequest $request): JsonResponse
    {
        $aspsps = array_map(fn ($aspsp) => $aspsp->toArray(), $this->connections->aspsps($request->country()));
        usort($aspsps, fn (array $left, array $right) => strcasecmp($left['name'], $right['name']));

        return response()->json(['data' => $aspsps]);
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $connections = BankConnection::query()->ownedBy($this->user($request))
            ->with('linkedAccounts')
            ->when(! $request->boolean('include_revoked'), fn ($query) => $query->where('status', '<>', BankConnectionStatus::Revoked->value))
            ->orderBy('aspsp_name')
            ->orderBy('created_at')
            ->get();

        return BankConnectionResource::collection($connections);
    }

    public function store(StoreBankConnectionRequest $request): JsonResponse
    {
        $url = $this->connections->start(
            $request->financeUser(),
            (string) $request->validated('aspsp_name'),
            strtoupper((string) $request->validated('aspsp_country')),
            $request->returnTarget(),
        );

        return response()->json(['data' => ['auth_url' => $url]], 201);
    }

    public function show(BankConnection $bankConnection): BankConnectionResource
    {
        $this->authorizeOwner('view', $bankConnection);

        return new BankConnectionResource($bankConnection);
    }

    public function accounts(BankConnection $bankConnection): JsonResponse
    {
        $this->authorizeOwner('view', $bankConnection);

        $linked = Account::query()->ownedBy($bankConnection->user_id)
            ->where('bank_connection_id', $bankConnection->id)
            ->whereNotNull('external_account_uid')
            ->get()
            ->keyBy('external_account_uid');

        $accounts = array_map(function (array $item) use ($linked): array {
            $bankAccount = BankAccount::fromArray($item);
            $account = $linked->get($bankAccount->uid);

            return [
                'external_account_uid' => $bankAccount->uid,
                'name' => $bankAccount->name,
                'iban' => $bankAccount->iban,
                'currency' => $bankAccount->currency,
                'type' => $bankAccount->type,
                'suggested_account_type' => $bankAccount->suggestedAccountType()->value,
                'linked_account' => $account === null ? null : [
                    'id' => $account->id,
                    'name' => $account->name,
                    'type' => $account->type->value,
                    'sync_from_date' => $account->sync_from_date?->toDateString(),
                ],
            ];
        }, $bankConnection->accounts ?? []);

        return response()->json(['data' => $accounts]);
    }

    public function link(LinkBankAccountsRequest $request, BankConnection $bankConnection): BankConnectionResource
    {
        $this->authorizeOwner('update', $bankConnection);

        return new BankConnectionResource($this->connections->link($bankConnection, $request->items(), $this->psu($request)));
    }

    public function sync(Request $request, BankConnection $bankConnection): JsonResponse
    {
        $this->authorizeOwner('update', $bankConnection);

        if (! $bankConnection->effectiveStatus()->isSyncable()) {
            throw ValidationException::withMessages(['connection' => 'La conexión no está activa. Renuévala para volver a sincronizar.']);
        }

        if (! SyncBankConnection::dispatchUnlessRunning($bankConnection->id, $this->psu($request))) {
            return response()->json(['data' => ['queued' => false, 'already_running' => true]]);
        }

        return response()->json(['data' => ['queued' => true, 'already_running' => false]], 202);
    }

    private function psu(Request $request): ?PsuContext
    {
        $ip = $request->ip();

        return $ip === null ? null : new PsuContext($ip, $request->userAgent());
    }

    public function renew(RenewBankConnectionRequest $request, BankConnection $bankConnection): JsonResponse
    {
        $this->authorizeOwner('update', $bankConnection);

        if ($bankConnection->status === BankConnectionStatus::Revoked) {
            throw ValidationException::withMessages(['connection' => 'Esta conexión está desconectada. Conecta el banco de nuevo.']);
        }

        return response()->json(['data' => ['auth_url' => $this->connections->renew($bankConnection, $request->returnTarget())]]);
    }

    public function destroy(BankConnection $bankConnection): Response
    {
        $this->authorizeOwner('delete', $bankConnection);
        $this->connections->revoke($bankConnection);

        return response()->noContent();
    }
}
