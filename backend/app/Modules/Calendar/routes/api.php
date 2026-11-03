<?php

use App\Modules\Calendar\Http\Controllers\CalendarController;
use App\Modules\Calendar\Http\Controllers\GoogleAccountController;
use App\Modules\Calendar\Http\Controllers\GoogleCalendarController;
use Illuminate\Support\Facades\Route;

$uuid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

Route::where(['account' => $uuid, 'calendar' => $uuid])->name('calendar.')->group(function (): void {
    Route::get('/', CalendarController::class)->name('index');

    Route::get('google/accounts', [GoogleAccountController::class, 'index'])->name('google.accounts.index');
    Route::post('google/accounts', [GoogleAccountController::class, 'connect'])->middleware('throttle:10,1')->name('google.accounts.connect');
    Route::post('google/accounts/{account}/sync', [GoogleAccountController::class, 'sync'])->middleware('throttle:6,1')->name('google.accounts.sync');
    Route::delete('google/accounts/{account}', [GoogleAccountController::class, 'destroy'])->name('google.accounts.destroy');
    Route::patch('google/calendars/{calendar}', [GoogleCalendarController::class, 'update'])->name('google.calendars.update');
});
