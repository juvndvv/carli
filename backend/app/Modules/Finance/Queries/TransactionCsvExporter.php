<?php

namespace App\Modules\Finance\Queries;

use App\Modules\Finance\Domain\Enums\TransactionKind;
use App\Modules\Finance\Domain\Enums\TransactionStatus;
use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Models\Tag;
use App\Modules\Finance\Models\Transaction;
use Illuminate\Database\Eloquent\Builder;
use Symfony\Component\HttpFoundation\StreamedResponse;

final class TransactionCsvExporter
{
    public const array HEADERS = ['Fecha', 'Cuenta', 'Tipo', 'Categoría', 'Subcategoría', 'Comercio', 'Concepto', 'Importe', 'Parte propia', 'Etiquetas', 'Estado', 'Notas'];

    private const array KIND_LABELS = [
        'expense' => 'Gasto',
        'income' => 'Ingreso',
        'transfer' => 'Transferencia',
        'adjustment' => 'Ajuste',
    ];

    /**
     * @param  Builder<Transaction>  $query
     */
    public function download(Builder $query): StreamedResponse
    {
        $filename = 'movimientos-'.SpanishCalendar::today()->toDateString().'.csv';

        return response()->streamDownload(function () use ($query): void {
            $handle = fopen('php://output', 'wb');
            if ($handle === false) {
                return;
            }

            fwrite($handle, "\u{FEFF}");
            fputcsv($handle, self::HEADERS, ';', '"', '');

            $query->clone()
                ->with(['account', 'category.parent', 'tags', 'shares'])
                ->orderBy('date')
                ->orderBy('id')
                ->chunk(500, function ($transactions) use ($handle): void {
                    foreach ($transactions as $transaction) {
                        fputcsv($handle, $this->row($transaction), ';', '"', '');
                    }
                });

            fclose($handle);
        }, $filename, ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    /**
     * @return list<string>
     */
    public function row(Transaction $transaction): array
    {
        $category = $transaction->category;
        $topLevel = $category === null ? null : ($category->parent ?? $category);
        $subcategory = $category !== null && $category->parent !== null ? $category->name : '';

        return [
            $transaction->date->format('d/m/Y'),
            $transaction->account->name,
            self::KIND_LABELS[$transaction->kind->value],
            $topLevel->name ?? '',
            $subcategory,
            $transaction->payee ?? '',
            $transaction->description ?? '',
            self::amount($transaction->amount_cents),
            $transaction->kind === TransactionKind::Expense ? self::amount($transaction->ownAmountCents()) : '',
            $transaction->tags->map(fn (Tag $tag) => $tag->name)->implode(', '),
            $transaction->status === TransactionStatus::Pending ? 'Pendiente' : 'Confirmado',
            $transaction->notes ?? '',
        ];
    }

    public static function amount(int $cents): string
    {
        $absolute = abs($cents);

        return ($cents < 0 ? '-' : '').intdiv($absolute, 100).','.str_pad((string) ($absolute % 100), 2, '0', STR_PAD_LEFT);
    }
}
