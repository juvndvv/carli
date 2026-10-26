<?php

use App\Modules\Notes\Http\Controllers\SearchController;
use App\Modules\Notes\Http\Controllers\SnapshotController;
use App\Modules\Notes\Http\Controllers\SyncController;
use Illuminate\Support\Facades\Route;

Route::name('notes.')->group(function (): void {
    Route::get('snapshot', SnapshotController::class)->name('snapshot');
    Route::post('sync', SyncController::class)->name('sync');
    Route::get('search', SearchController::class)->name('search');
});
