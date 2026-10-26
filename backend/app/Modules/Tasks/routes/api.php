<?php

use App\Modules\Tasks\Http\Controllers\AgendaController;
use App\Modules\Tasks\Http\Controllers\SubtaskController;
use App\Modules\Tasks\Http\Controllers\TaskController;
use App\Modules\Tasks\Http\Controllers\TaskListController;
use App\Modules\Tasks\Http\Controllers\TemplateController;
use Illuminate\Support\Facades\Route;

$uuid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

Route::where([
    'list' => $uuid,
    'task' => $uuid,
    'subtask' => $uuid,
    'template' => $uuid,
])->name('tasks.')->group(function (): void {
    Route::get('today', [AgendaController::class, 'today'])->name('today');
    Route::get('upcoming', [AgendaController::class, 'upcoming'])->name('upcoming');

    Route::put('lists/order', [TaskListController::class, 'reorder'])->name('lists.reorder');
    Route::apiResource('lists', TaskListController::class);

    Route::post('tasks/{task}/complete', [TaskController::class, 'complete'])->name('tasks.complete');
    Route::post('tasks/{task}/reopen', [TaskController::class, 'reopen'])->name('tasks.reopen');
    Route::post('tasks/{task}/skip', [TaskController::class, 'skip'])->name('tasks.skip');
    Route::post('tasks/{task}/postpone', [TaskController::class, 'postpone'])->name('tasks.postpone');
    Route::apiResource('tasks', TaskController::class);

    Route::post('tasks/{task}/subtasks', [SubtaskController::class, 'store'])->name('subtasks.store');
    Route::patch('tasks/{task}/subtasks/{subtask}', [SubtaskController::class, 'update'])->name('subtasks.update');
    Route::delete('tasks/{task}/subtasks/{subtask}', [SubtaskController::class, 'destroy'])->name('subtasks.destroy');

    Route::post('templates/preview', [TemplateController::class, 'preview'])->name('templates.preview');
    Route::post('templates/{template}/pause', [TemplateController::class, 'pause'])->name('templates.pause');
    Route::post('templates/{template}/resume', [TemplateController::class, 'resume'])->name('templates.resume');
    Route::post('templates/{template}/skip', [TemplateController::class, 'skip'])->name('templates.skip');
    Route::post('templates/{template}/unskip', [TemplateController::class, 'unskip'])->name('templates.unskip');
    Route::get('templates/{template}/history', [TemplateController::class, 'history'])->name('templates.history');
    Route::apiResource('templates', TemplateController::class);
});
