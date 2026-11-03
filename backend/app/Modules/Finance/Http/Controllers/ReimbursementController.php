<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Services\ReimbursementService;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Http\Requests\ReimbursementCandidatesRequest;
use App\Modules\Finance\Http\Requests\StoreReimbursementRequest;
use App\Modules\Finance\Http\Resources\TransactionResource;
use App\Modules\Finance\Models\Contact;
use App\Modules\Finance\Models\SharedExpenseShare;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

final class ReimbursementController extends FinanceController
{
    public function __construct(private readonly ReimbursementService $reimbursements) {}

    /**
     * Incomes that can pay back an expense or a contact's shares, or expenses an income can pay back.
     */
    public function candidates(ReimbursementCandidatesRequest $request): JsonResponse
    {
        $user = $request->financeUser();
        $data = $request->validated();

        if (isset($data['income_id'])) {
            $income = Transaction::query()->ownedBy($user)->findOrFail((string) $data['income_id']);
            $transactions = $this->reimbursements->expenseCandidates($income);
        } elseif (isset($data['expense_id'])) {
            $expense = Transaction::query()->ownedBy($user)->findOrFail((string) $data['expense_id']);
            $transactions = $this->reimbursements->incomeCandidates($user->id, $expense->date);
        } elseif (isset($data['contact_id'])) {
            $oldest = SharedExpenseShare::query()
                ->where('contact_id', (string) $data['contact_id'])
                ->whereNull('settled_at')
                ->join('finance.transactions as t', 't.id', '=', 'finance.shared_expense_shares.transaction_id')
                ->whereNull('t.deleted_at')
                ->min('t.date');
            $transactions = $this->reimbursements->incomeCandidates($user->id, is_string($oldest) ? SpanishCalendar::date($oldest) : null);
        } else {
            throw ValidationException::withMessages(['expense_id' => 'Indica un gasto, un ingreso o un contacto.']);
        }

        $transactions->load(TransactionResource::RELATIONS);

        return response()->json(['data' => TransactionResource::collection($transactions)->resolve($request)]);
    }

    public function store(StoreReimbursementRequest $request): JsonResponse
    {
        $user = $request->financeUser();
        $expense = Transaction::query()->ownedBy($user)->findOrFail((string) $request->validated('expense_id'));
        $contact = Contact::query()->ownedBy($user)->findOrFail((string) $request->validated('contact_id'));

        /** @var list<string> $incomeIds */
        $incomeIds = array_values(array_map('strval', (array) $request->validated('income_ids')));
        $result = $this->reimbursements->reimburseExpense($expense, $contact, $incomeIds);

        return response()->json(['data' => [
            'expense' => (new TransactionResource($result['expense']))->resolve($request),
            'incomes' => array_map(fn (Transaction $income) => (new TransactionResource($income))->resolve($request), $result['incomes']),
        ]], 201);
    }

    public function destroy(Request $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeOwner('update', $transaction);

        if ($transaction->kind !== TransactionKind::Income) {
            throw ValidationException::withMessages(['transaction' => 'Solo los ingresos pueden ser reembolsos.']);
        }

        $this->reimbursements->unlink($transaction);

        return response()->json(['data' => (new TransactionResource($transaction->refresh()))->resolve($request)]);
    }
}
