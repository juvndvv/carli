<?php

use App\Core\Http\Controllers\AccessTokenController;
use App\Core\Http\Controllers\MeController;
use App\Core\Http\Controllers\ModuleController;
use App\Core\Http\Controllers\NotificationController;
use App\Core\Http\Controllers\NotificationPreferenceController;
use App\Core\Http\Controllers\PasswordController;
use App\Core\Http\Controllers\PendingController;
use App\Core\Http\Controllers\PersonalAccessTokenController;
use App\Core\Http\Controllers\PushSubscriptionController;
use App\Core\Http\Controllers\SearchController;
use App\Core\Http\Controllers\SessionController;
use App\Core\Http\Controllers\TwoFactorController;
use Illuminate\Support\Facades\Route;

Route::post('v1/auth/token', [AccessTokenController::class, 'store'])
    ->middleware('throttle:login')
    ->name('auth.token.store');

Route::prefix('v1')->middleware('auth:sanctum')->group(function (): void {
    Route::delete('auth/token', [AccessTokenController::class, 'destroy'])->name('auth.token.destroy');

    Route::get('me', [MeController::class, 'show'])->name('me.show');
    Route::patch('me', [MeController::class, 'update'])->name('me.update');
    Route::patch('me/preferences', [MeController::class, 'updatePreferences'])->name('me.preferences.update');

    Route::get('me/sessions', [SessionController::class, 'index'])->name('me.sessions.index');
    Route::post('me/sessions/logout-others', [SessionController::class, 'destroyOthers'])->name('me.sessions.logout-others');
    Route::delete('me/sessions/{session}', [SessionController::class, 'destroy'])->name('me.sessions.destroy');

    Route::get('me/tokens', [PersonalAccessTokenController::class, 'index'])->name('me.tokens.index');
    Route::delete('me/tokens/{token}', [PersonalAccessTokenController::class, 'destroy'])
        ->whereNumber('token')
        ->name('me.tokens.destroy');

    Route::middleware('throttle:10,1')->group(function (): void {
        Route::put('me/password', [PasswordController::class, 'update'])->name('me.password.update');
        Route::post('me/tokens/logout-others', [PersonalAccessTokenController::class, 'destroyOthers'])->name('me.tokens.logout-others');

        Route::post('me/two-factor', [TwoFactorController::class, 'store'])->name('me.two-factor.store');
        Route::post('me/two-factor/confirm', [TwoFactorController::class, 'confirm'])->name('me.two-factor.confirm');
        Route::delete('me/two-factor', [TwoFactorController::class, 'destroy'])->name('me.two-factor.destroy');
        Route::post('me/two-factor/recovery-codes', [TwoFactorController::class, 'recoveryCodes'])->name('me.two-factor.recovery-codes.show');
        Route::post('me/two-factor/recovery-codes/regenerate', [TwoFactorController::class, 'regenerateRecoveryCodes'])->name('me.two-factor.recovery-codes.regenerate');
    });

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

    Route::get('pending/summary', [PendingController::class, 'summary'])->name('pending.summary');
    Route::get('pending', [PendingController::class, 'index'])->name('pending.index');

    Route::get('search', SearchController::class)->name('search');
});
