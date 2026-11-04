<?php

use App\Modules\Health\Http\Controllers\BodyController;
use App\Modules\Health\Http\Controllers\MeasurementController;
use App\Modules\Health\Http\Controllers\SettingsController;
use App\Modules\Health\Http\Controllers\SummaryController;
use App\Modules\Health\Http\Controllers\WhoopController;
use Illuminate\Support\Facades\Route;

Route::where([
    'measurement' => '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    'site' => '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    'bodyMeasurement' => '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
])->name('health.')->group(function (): void {
    Route::get('summary', SummaryController::class)->name('summary');

    Route::get('settings', [SettingsController::class, 'show'])->name('settings.show');
    Route::put('settings', [SettingsController::class, 'update'])->name('settings.update');

    Route::get('measurements', [MeasurementController::class, 'index'])->name('measurements.index');
    Route::post('measurements', [MeasurementController::class, 'store'])->name('measurements.store');
    Route::post('measurements/sync', [MeasurementController::class, 'sync'])->name('measurements.sync');
    Route::get('measurements/{measurement}', [MeasurementController::class, 'show'])->name('measurements.show');
    Route::delete('measurements/{measurement}', [MeasurementController::class, 'destroy'])->name('measurements.destroy');

    Route::prefix('whoop')->name('whoop.')->group(function (): void {
        Route::get('/', [WhoopController::class, 'show'])->name('show');
        Route::post('/', [WhoopController::class, 'connect'])->middleware('throttle:10,1')->name('connect');
        Route::post('sync', [WhoopController::class, 'sync'])->middleware('throttle:6,1')->name('sync');
        Route::delete('/', [WhoopController::class, 'destroy'])->name('destroy');
        Route::get('days', [WhoopController::class, 'days'])->name('days');
    });

    Route::prefix('body')->name('body.')->group(function (): void {
        Route::get('/', [BodyController::class, 'overview'])->name('overview');
        Route::get('sites', [BodyController::class, 'sites'])->name('sites.index');
        Route::post('sites', [BodyController::class, 'storeSite'])->name('sites.store');
        Route::put('sites/order', [BodyController::class, 'reorder'])->name('sites.reorder');
        Route::patch('sites/{site}', [BodyController::class, 'updateSite'])->name('sites.update');
        Route::delete('sites/{site}', [BodyController::class, 'destroySite'])->name('sites.destroy');
        Route::get('sites/{site}/measurements', [BodyController::class, 'history'])->name('sites.history');
        Route::post('measurements', [BodyController::class, 'record'])->name('measurements.store');
        Route::delete('measurements/{bodyMeasurement}', [BodyController::class, 'destroyMeasurement'])->name('measurements.destroy');
    });
});
