<?php

return [
    'name' => $_ENV['APP_NAME'] ?? 'ThirdBooks Admin',
    'env' => $_ENV['APP_ENV'] ?? 'production',
    'debug' => filter_var($_ENV['APP_DEBUG'] ?? false, FILTER_VALIDATE_BOOLEAN),
    'url' => $_ENV['APP_URL'] ?? 'http://localhost:8080',

    'api' => [
        'base_url' => $_ENV['API_BASE_URL'] ?? 'http://localhost:8000/api',
        'timeout' => (int) ($_ENV['API_TIMEOUT'] ?? 30),
    ],

    'session' => [
        'lifetime' => (int) ($_ENV['SESSION_LIFETIME'] ?? 120),
        'secure' => filter_var($_ENV['SESSION_SECURE'] ?? false, FILTER_VALIDATE_BOOLEAN),
    ],
];
