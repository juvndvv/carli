<?php

namespace App\Modules\Finance\Http\Resources;

use App\Modules\Finance\Domain\Services\ContactService;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\Debt;
use App\Modules\Finance\Models\SharedExpenseShare;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Contact
 */
final class ContactResource extends JsonResource
{
    public bool $withDetail = false;

    public function detailed(): self
    {
        $this->withDetail = true;

        return $this;
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        /** @var Contact $contact */
        $contact = $this->resource;
        $contacts = app(ContactService::class);

        $data = [
            'id' => $contact->id,
            'name' => $contact->name,
            'notes' => $contact->notes,
            'archived' => $contact->archived_at !== null,
            ...$contacts->balance($contact),
        ];

        if (! $this->withDetail) {
            return $data;
        }

        $shares = SharedExpenseShare::query()
            ->where('contact_id', $contact->id)
            ->whereHas('transaction', fn ($query) => $query->whereNull('deleted_at'))
            ->with('transaction')
            ->get()
            ->sortByDesc(fn (SharedExpenseShare $share) => $share->transaction->date->toDateString())
            ->values();

        $data['shares'] = $shares->map(fn (SharedExpenseShare $share) => [
            'id' => $share->id,
            'transaction_id' => $share->transaction_id,
            'date' => $share->transaction->date->toDateString(),
            'payee' => $share->transaction->payee,
            'description' => $share->transaction->description,
            'transaction_amount_cents' => $share->transaction->amount_cents,
            'amount_cents' => $share->amount_cents,
            'settled' => $share->settled_at !== null,
            'settled_at' => $share->settled_at?->toIso8601String(),
            'settlement_transaction_id' => $share->settlement_transaction_id,
        ])->all();

        $data['debts'] = DebtResource::collection(
            Debt::query()->ownedBy($contact->user_id)->where('contact_id', $contact->id)->orderBy('start_date')->get()
        )->resolve($request);

        return $data;
    }
}
