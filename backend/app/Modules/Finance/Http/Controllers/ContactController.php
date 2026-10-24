<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Services\ContactService;
use App\Modules\Finance\Http\Requests\SettleContactRequest;
use App\Modules\Finance\Http\Requests\StoreContactRequest;
use App\Modules\Finance\Http\Resources\ContactResource;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Contact;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

final class ContactController extends FinanceController
{
    public function __construct(private readonly ContactService $contacts) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $contacts = Contact::query()->ownedBy($this->user($request))
            ->when(! $request->boolean('include_archived'), fn ($query) => $query->whereNull('archived_at'))
            ->orderBy('name')
            ->get();

        $balances = $contacts->map(fn (Contact $contact) => $this->contacts->balance($contact)['balance_cents']);

        return ContactResource::collection($contacts)->additional(['meta' => [
            'owed_to_me_cents' => $balances->filter(fn (int $balance) => $balance > 0)->sum(),
            'i_owe_cents' => -$balances->filter(fn (int $balance) => $balance < 0)->sum(),
        ]]);
    }

    public function store(StoreContactRequest $request): JsonResponse
    {
        $contact = $this->contacts->create($request->financeUser(), (string) $request->validated('name'), $request->validated('notes'));

        return (new ContactResource($contact))->detailed()->response()->setStatusCode(201);
    }

    public function show(Contact $contact): ContactResource
    {
        $this->authorizeOwner('view', $contact);

        return (new ContactResource($contact))->detailed();
    }

    public function update(StoreContactRequest $request, Contact $contact): ContactResource
    {
        $this->authorizeOwner('update', $contact);
        $data = $request->validated();
        $contact->fill(array_intersect_key($data, array_flip(['name', 'notes'])));

        if (array_key_exists('archived', $data)) {
            $contact->archived_at = $data['archived'] ? ($contact->archived_at ?? CarbonImmutable::now()) : null;
        }

        $contact->save();

        return (new ContactResource($contact))->detailed();
    }

    public function destroy(Contact $contact): Response
    {
        $this->authorizeOwner('delete', $contact);
        $this->contacts->delete($contact);

        return response()->noContent();
    }

    public function settle(SettleContactRequest $request, Contact $contact): JsonResponse
    {
        $this->authorizeOwner('update', $contact);

        /** @var array{account_id: string, date?: string|null} $data */
        $data = $request->validated();
        $settlement = $this->contacts->settle($contact, $data);

        return response()->json(['data' => [
            'transaction' => (new TransactionResource($settlement['transaction']))->resolve($request),
            'transactions' => array_map(fn ($transaction) => (new TransactionResource($transaction))->resolve($request), $settlement['transactions']),
            'net_cents' => $settlement['net_cents'],
            'contact' => (new ContactResource($contact->refresh()))->resolve($request),
        ]], 201);
    }
}
