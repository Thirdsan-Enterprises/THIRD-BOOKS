<?php

namespace App\Console\Commands;

use App\Services\TenantService;
use Database\Seeders\OutletSeeder;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SeedOutlets extends Command
{
    protected $signature = 'magicbet:seed-outlets
                            {--tenant= : Seed a specific tenant ID only}
                            {--all    : Seed all tenants (default)}';

    protected $description = 'Seed the 72 MagicBet outlets into the tenant database(s)';

    public function handle(): int
    {
        $tenantId = $this->option('tenant');

        $tenants = $tenantId
            ? [DB::table('tenants')->where('id', $tenantId)->first()]
            : DB::table('tenants')->get()->all();

        if (empty($tenants) || ($tenantId && !$tenants[0])) {
            $this->error('No tenants found.');
            return 1;
        }

        foreach ($tenants as $tenant) {
            if (!$tenant) continue;

            $this->info("Seeding outlets for tenant: {$tenant->id} ({$tenant->name})");

            // Switch to the tenant's database connection
            $dbName = 'tenant_' . $tenant->id;
            config(['database.connections.tenant_mysql.database' => $dbName]);
            DB::purge('tenant_mysql');

            try {
                $seeder = new OutletSeeder();
                $seeder->setCommand($this);
                $seeder->run();
            } catch (\Throwable $e) {
                $this->error("  Failed for tenant {$tenant->id}: " . $e->getMessage());
            }
        }

        $this->info('Done.');
        return 0;
    }
}
