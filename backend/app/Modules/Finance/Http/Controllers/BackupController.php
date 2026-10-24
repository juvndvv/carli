<?php

namespace App\Modules\Finance\Http\Controllers;

use App\Modules\Finance\Domain\Support\SpanishCalendar;
use App\Modules\Finance\Queries\FinanceBackup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class BackupController extends FinanceController
{
    public function __invoke(Request $request, FinanceBackup $backup): JsonResponse
    {
        $filename = 'finanzas-backup-'.SpanishCalendar::today()->toDateString().'.json';

        return response()
            ->json($backup->export($this->user($request)->id), 200, [], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT)
            ->header('Content-Disposition', 'attachment; filename="'.$filename.'"');
    }
}
