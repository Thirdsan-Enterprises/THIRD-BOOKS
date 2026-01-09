<?php

declare(strict_types=1);

return [
    'tenant_model' => \App\Models\Tenant\Tenant::class,
    'id_generator' => \Stancl\Tenancy\UUIDGenerator::class,

    'domain_model' => \App\Models\Tenant\Domain::class,

    /**
     * Multi-tenancy mode:
     * - 'single' => Shared database, tenant_id in all tables
     * - 'multi' => Separate database per tenant
     */
    'tenancy_mode' => env('TENANCY_MODE', 'single'),

    'central_domains' => explode(',', env('CENTRAL_DOMAINS', 'localhost')),

    'bootstrappers' => [
        Stancl\Tenancy\Bootstrappers\DatabaseTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\CacheTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\FilesystemTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\QueueTenancyBootstrapper::class,
    ],

    'database' => [
        'central_connection' => env('DB_CONNECTION', 'pgsql'),
        'tenant_connection' => env('TENANT_DB_CONNECTION', 'tenant_pgsql'),

        'prefix' => 'tenant',
        'suffix' => '',

        'managers' => [
            'sqlite' => Stancl\Tenancy\Database\TenantDatabaseManagers\SQLiteDatabaseManager::class,
            'pgsql' => Stancl\Tenancy\Database\TenantDatabaseManagers\PostgreSQLDatabaseManager::class,
        ],
    ],

    'cache' => [
        'tag_base' => 'tenant',
    ],

    'filesystem' => [
        'suffix_base' => 'tenant',
        'disks' => [
            'local',
            'public',
            's3',
        ],

        'root_override' => [
            'local' => '%storage_path%/app/tenant%tenant_id%',
            'public' => '%storage_path%/app/public/tenant%tenant_id%',
        ],

        'url_override' => [
            'public' => '/storage/tenant%tenant_id%',
        ],

        'asset_helper_tenancy' => true,
    ],

    'redis' => [
        'prefix_base' => 'tenant',
        'prefixed_connections' => [
            'default',
            'cache',
            'queue',
        ],
    ],

    'features' => [
        Stancl\Tenancy\Features\UserImpersonation::class,
        Stancl\Tenancy\Features\TelescopeTags::class,
        Stancl\Tenancy\Features\TenantConfig::class,
        Stancl\Tenancy\Features\Timestamps::class,
    ],

    'migration_parameters' => [
        '--force' => true,
        '--path' => [database_path('migrations/tenant')],
        '--realpath' => true,
    ],

    'seeder_parameters' => [
        '--class' => 'TenantDatabaseSeeder',
    ],
];
