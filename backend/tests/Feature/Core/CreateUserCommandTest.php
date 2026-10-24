<?php

use App\Models\User;
use Illuminate\Support\Facades\Hash;

it('creates a user non interactively', function () {
    $this->artisan('app:create-user', [
        '--name' => 'Juanda',
        '--email' => 'Juanda@Example.com',
        '--password' => 'a-Secure-passw0rd',
        '--no-interaction' => true,
    ])->assertSuccessful();

    $user = User::query()->where('email', 'juanda@example.com')->sole();

    expect($user->name)->toBe('Juanda')
        ->and(Hash::check('a-Secure-passw0rd', $user->password))->toBeTrue();
});

it('creates a user interactively', function () {
    $this->artisan('app:create-user')
        ->expectsQuestion('Nombre', 'Interactive')
        ->expectsQuestion('Email', 'interactive@example.com')
        ->expectsQuestion('Contraseña', 'a-Secure-passw0rd')
        ->assertSuccessful();

    expect(User::query()->where('email', 'interactive@example.com')->exists())->toBeTrue();
});

it('fails without options in non interactive mode', function () {
    $this->artisan('app:create-user', ['--no-interaction' => true])->assertFailed();

    expect(User::query()->count())->toBe(0);
});

it('fails when the email is already taken', function () {
    User::factory()->create(['email' => 'taken@example.com']);

    $this->artisan('app:create-user', [
        '--name' => 'Dup',
        '--email' => 'taken@example.com',
        '--password' => 'a-Secure-passw0rd',
        '--no-interaction' => true,
    ])->assertFailed();
});
