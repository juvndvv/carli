<?php

use App\Core\Http\Controllers\MeController;
use App\Core\Http\Controllers\ModuleController;
use App\Core\Http\Controllers\NotificationController;
use App\Core\Http\Controllers\NotificationPreferenceController;
use App\Core\Http\Controllers\PushSubscriptionController;
use App\Core\Http\Controllers\SearchController;
use App\Core\Http\Controllers\SessionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware('auth:sanctum')->group(function (): void {
    Route::get('me', [MeController::class, 'show'])->name('me.show');
    Route::patch('me', [MeController::class, 'update'])->name('me.update');
    Route::patch('me/preferences', [MeController::class, 'updatePreferences'])->name('me.preferences.update');

    Route::get('me/sessions', [SessionController::class, 'index'])->name('me.sessions.index');
    Route::post('me/sessions/logout-others', [SessionController::class, 'destroyOthers'])->name('me.sessions.logout-others');
    Route::delete('me/sessions/{session}', [SessionController::class, 'destroy'])->name('me.sessions.destroy');

    Route::get('modules', [ModuleController::class, 'index'])->name('modules.index');
    Route::patch('modules/{module}', [ModuleController::class, 'update'])->name('modules.update');

    Route::get('notifications', [NotificationController::class, 'index'])->name('notifications.index');
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount'])->name('notifications.unread-count');
    Route::post('notifications/read', [NotificationController::class, 'markRead'])->name('notifications.read');
    Route::post('notifications/test', [NotificationController::class, 'test'])
        ->middleware('throttle:10,1')
        ->name('notifications.test');

    Route::get('notification-preferences', [NotificationPreferenceController::class, 'index'])->name('notification-preferences.index');
    Route::put('notification-preferences', [NotificationPreferenceController::class, 'update'])->name('notification-preferences.update');

    Route::get('push/public-key', [PushSubscriptionController::class, 'publicKey'])->name('push.public-key');
    Route::post('push-subscriptions', [PushSubscriptionController::class, 'store'])->name('push-subscriptions.store');
    Route::delete('push-subscriptions', [PushSubscriptionController::class, 'destroy'])->name('push-subscriptions.destroy');

    Route::get('search', SearchController::class)->name('search');
});
