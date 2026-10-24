<?php

use App\Models\User;
use Database\Seeders\DatabaseSeeder;

it('does not create the demo user unless enabled', function () {
    config(['app.seed_demo_user' => false]);

    $this->seed(DatabaseSeeder::class);

    expect(User::query()->where('email', DatabaseSeeder::DEMO_EMAIL)->exists())->toBeFalse();
});

it('creates the demo user when enabled', function () {
    config(['app.seed_demo_user' => true]);

    $this->seed(DatabaseSeeder::class);
    $this->seed(DatabaseSeeder::class);

    expect(User::query()->where('email', DatabaseSeeder::DEMO_EMAIL)->count())->toBe(1);

    $this->postJson('/login', ['email' => DatabaseSeeder::DEMO_EMAIL, 'password' => DatabaseSeeder::DEMO_PASSWORD])
        ->assertOk();
});
