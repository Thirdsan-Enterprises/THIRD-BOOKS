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
        // DatabaseTenancyBootstrapper is for multi-database tenancy only.
        // In single-database mode (TENANCY_MODE=single) it tries to switch
        // the DB connection to a per-tenant database that doesn't exist → 500.
        // Stancl\Tenancy\Bootstrappers\DatabaseTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\CacheTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\FilesystemTenancyBootstrapper::class,
        Stancl\Tenancy\Bootstrappers\QueueTenancyBootstrapper::class,
    ],

    'database' => [
        /*
        |--------------------------------------------------------------------------
        | Database Connections for Multi-Tenancy
        |--------------------------------------------------------------------------
        |
        | Default: MySQL (DirectAdmin compatible)
        | Set DB_CONNECTION=pgsql and TENANT_DB_CONNECTION=tenant_pgsql for PostgreSQL
        |
        */
        'central_connection' => env('DB_CONNECTION', 'mysql'),
        'tenant_connection' => env('TENANT_DB_CONNECTION', 'tenant_mysql'),

        'prefix' => 'tenant_',
        'suffix' => '',

        'managers' => [
            'sqlite' => Stancl\Tenancy\Database\TenantDatabaseManagers\SQLiteDatabaseManager::class,
            'mysql' => Stancl\Tenancy\Database\TenantDatabaseManagers\MySQLDatabaseManager::class,
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
