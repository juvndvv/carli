<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'enable_banking' => [
        'base_url' => env('ENABLE_BANKING_BASE_URL', 'https://api.enablebanking.com'),
        'app_id' => env('ENABLE_BANKING_APP_ID'),
        'private_key_path' => env('ENABLE_BANKING_PRIVATE_KEY_PATH', '/run/secrets/enable_banking.pem'),
        'redirect_url' => env('ENABLE_BANKING_REDIRECT_URL'),
        'country' => env('ENABLE_BANKING_COUNTRY', 'ES'),
        'jwt_ttl' => (int) env('ENABLE_BANKING_JWT_TTL', 3600),
        'timeout' => (int) env('ENABLE_BANKING_TIMEOUT', 30),
        'backoff_ms' => [500, 2000, 5000],
    ],

];
