<?php

namespace Database\Seeders;

use App\Models\Company;
use Illuminate\Database\Seeder;

class TenantDatabaseSeeder extends Seeder
{
    /**
     * Seed the tenant's database.
     */
    public function run(): void
    {
        // Get the first company in this tenant database
        $company = Company::first();

        if (!$company) {
            $this->command->error('No company found. Please create a company first.');
            return;
        }

        // Seed Chart of Accounts
        $chartOfAccountsSeeder = new ChartOfAccountsSeeder();
        $chartOfAccountsSeeder->run($company, 'general');

        $this->command->info('Tenant database seeded successfully!');
    }
}
