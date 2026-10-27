<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

pest()->extend(TestCase::class)
    ->use(RefreshDatabase::class)
    ->in('Feature', '../app/Modules');

function configureApns(bool $configured = true): void
{
    if (! $configured) {
        config(['services.apns.key_id' => null, 'services.apns.team_id' => null, 'services.apns.private_key_path' => null]);

        return;
    }

    $path = sys_get_temp_dir().'/carli-tests-apns.p8';

    if (! is_file($path)) {
        $key = openssl_pkey_new(['curve_name' => 'prime256v1', 'private_key_type' => OPENSSL_KEYTYPE_EC]);
        openssl_pkey_export($key, $pem);
        file_put_contents($path, $pem);
    }

    config([
        'services.apns.key_id' => 'KEYID12345',
        'services.apns.team_id' => 'S5FFHKW385',
        'services.apns.bundle_id' => 'dev.jotade.personal',
        'services.apns.private_key_path' => $path,
    ]);
}
