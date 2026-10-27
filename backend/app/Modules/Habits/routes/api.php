<?php

use App\Modules\Habits\Http\Controllers\AgendaController;
use App\Modules\Habits\Http\Controllers\BreakController;
use App\Modules\Habits\Http\Controllers\ConversionController;
use App\Modules\Habits\Http\Controllers\EntryController;
use App\Modules\Habits\Http\Controllers\HabitController;
use Illuminate\Support\Facades\Route;

$uuid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

Route::where([
    'habit' => $uuid,
    'break' => $uuid,
    'template' => $uuid,
    'date' => '\d{4}-\d{2}-\d{2}',
])->name('habits.')->group(function (): void {
    Route::get('today', [AgendaController::class, 'today'])->name('today');
    Route::get('progress', [AgendaController::class, 'progress'])->name('progress');

    Route::get('breaks', [BreakController::class, 'index'])->name('breaks.index');
    Route::post('breaks', [BreakController::class, 'store'])->name('breaks.store');
    Route::patch('breaks/{break}', [BreakController::class, 'update'])->name('breaks.update');
    Route::post('breaks/{break}/end', [BreakController::class, 'end'])->name('breaks.end');
    Route::delete('breaks/{break}', [BreakController::class, 'destroy'])->name('breaks.destroy');

    Route::get('conversions/{template}', [ConversionController::class, 'preview'])->name('conversions.preview');
    Route::post('conversions', [ConversionController::class, 'store'])->name('conversions.store');

    Route::put('order', [HabitController::class, 'reorder'])->name('reorder');
    Route::get('/', [HabitController::class, 'index'])->name('index');
    Route::post('/', [HabitController::class, 'store'])->name('store');
    Route::get('{habit}', [HabitController::class, 'show'])->name('show');
    Route::patch('{habit}', [HabitController::class, 'update'])->name('update');
    Route::delete('{habit}', [HabitController::class, 'destroy'])->name('destroy');
    Route::post('{habit}/pause', [HabitController::class, 'pause'])->name('pause');
    Route::post('{habit}/resume', [HabitController::class, 'resume'])->name('resume');
    Route::post('{habit}/archive', [HabitController::class, 'archive'])->name('archive');
    Route::post('{habit}/unarchive', [HabitController::class, 'unarchive'])->name('unarchive');
    Route::get('{habit}/calendar', [HabitController::class, 'calendar'])->name('calendar');
    Route::put('{habit}/entries/{date}', [EntryController::class, 'update'])->name('entries.update');
    Route::delete('{habit}/entries/{date}', [EntryController::class, 'destroy'])->name('entries.destroy');
});
