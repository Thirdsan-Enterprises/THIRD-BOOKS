<?php

namespace App\Services;

use App\Models\Tenant\Tenant;
use App\Models\Company;
use App\Models\User;
use App\Models\Currency;
use App\Models\Accounting\Account;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class TenantService
{
    /**
     * Provision a new tenant with full setup
     *
     * @param array $data Registration data
     * @return array Tenant, User, and Company
     */
    public function provisionTenant(array $data): array
    {
        return DB::transaction(function () use ($data) {
            // 1. Create the tenant
            $tenant = $this->createTenant($data);

            // 2. Create the primary domain
            $domain = $this->createDomain($tenant, $data['company_name']);

            // 3. Create the admin user
            $user = $this->createAdminUser($tenant, $data);

            // 4. Create the default company
            $company = $this->createDefaultCompany($tenant, $data);

            // 5. Setup default chart of accounts
            $this->setupDefaultChartOfAccounts($company);

            // 6. Setup default currencies
            $this->setupDefaultCurrencies($tenant);

            return [
                'tenant' => $tenant,
                'user' => $user,
                'company' => $company,
                'domain' => $domain,
            ];
        });
    }

    /**
     * Create a new tenant
     */
    protected function createTenant(array $data): Tenant
    {
        return Tenant::create([
            'name' => $data['company_name'],
            'company_name' => $data['company_name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'country' => $data['country'] ?? 'UG',
            'base_currency' => $data['base_currency'] ?? 'UGX',
            'plan' => 'trial',
            'trial_ends_at' => now()->addDays(30),
            'status' => 'active',
            'settings' => [
                'date_format' => 'Y-m-d',
                'time_format' => 'H:i:s',
                'timezone' => 'Africa/Kampala',
                'decimal_places' => 2,
                'thousand_separator' => ',',
                'decimal_separator' => '.',
            ],
        ]);
    }

    /**
     * Create primary domain for tenant
     */
    protected function createDomain(Tenant $tenant, string $companyName): \App\Models\Tenant\Domain
    {
        $subdomain = Str::slug($companyName);
        $baseDomain = config('app.tenant_domain', 'thirdbooks.digital');

        // Ensure unique subdomain
        $originalSubdomain = $subdomain;
        $counter = 1;
        while (\App\Models\Tenant\Domain::where('domain', $subdomain . '.' . $baseDomain)->exists()) {
            $subdomain = $originalSubdomain . $counter;
            $counter++;
        }

        return $tenant->domains()->create([
            'domain' => $subdomain . '.' . $baseDomain,
            'is_primary' => true,
        ]);
    }

    /**
     * Create admin user for tenant
     */
    protected function createAdminUser(Tenant $tenant, array $data): User
    {
        return User::create([
            'tenant_id' => $tenant->id,
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'phone' => $data['phone'] ?? null,
            'role' => User::ROLE_ADMIN,
            'is_active' => true,
            'email_verified_at' => now(),
        ]);
    }

    /**
     * Create default company for tenant
     */
    protected function createDefaultCompany(Tenant $tenant, array $data): Company
    {
        return Company::create([
            'tenant_id' => $tenant->id,
            'name' => $data['company_name'],
            'legal_name' => $data['company_name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'country' => $data['country'] ?? 'UG',
            'base_currency' => $data['base_currency'] ?? 'UGX',
            'fiscal_year_start' => '01-01',
            'fiscal_year_end' => '12-31',
            'settings' => [
                'invoice_prefix' => 'INV',
                'invoice_starting_number' => 1,
                'bill_prefix' => 'BILL',
                'bill_starting_number' => 1,
                'payment_prefix' => 'PMT',
                'payment_starting_number' => 1,
            ],
        ]);
    }

    /**
     * Setup default chart of accounts
     */
    protected function setupDefaultChartOfAccounts(Company $company): void
    {
        $accounts = [
            // Assets (1xxx)
            ['code' => '1000', 'name' => 'Cash', 'type' => 'asset', 'category' => 'cash', 'is_system' => true],
            ['code' => '1010', 'name' => 'Petty Cash', 'type' => 'asset', 'category' => 'cash'],
            ['code' => '1100', 'name' => 'Bank Account', 'type' => 'asset', 'category' => 'bank', 'is_system' => true],
            ['code' => '1200', 'name' => 'Accounts Receivable', 'type' => 'asset', 'category' => 'accounts_receivable', 'is_system' => true],
            ['code' => '1300', 'name' => 'Inventory', 'type' => 'asset', 'category' => 'inventory'],
            ['code' => '1400', 'name' => 'Prepaid Expenses', 'type' => 'asset', 'category' => 'other_current_asset'],
            ['code' => '1500', 'name' => 'Equipment', 'type' => 'asset', 'category' => 'fixed_asset'],
            ['code' => '1510', 'name' => 'Accumulated Depreciation - Equipment', 'type' => 'asset', 'category' => 'fixed_asset'],
            ['code' => '1600', 'name' => 'Vehicles', 'type' => 'asset', 'category' => 'fixed_asset'],
            ['code' => '1610', 'name' => 'Accumulated Depreciation - Vehicles', 'type' => 'asset', 'category' => 'fixed_asset'],

            // Liabilities (2xxx)
            ['code' => '2000', 'name' => 'Accounts Payable', 'type' => 'liability', 'category' => 'accounts_payable', 'is_system' => true],
            ['code' => '2100', 'name' => 'Credit Card', 'type' => 'liability', 'category' => 'credit_card'],
            ['code' => '2200', 'name' => 'VAT Payable', 'type' => 'liability', 'category' => 'other_current_liability'],
            ['code' => '2300', 'name' => 'PAYE Payable', 'type' => 'liability', 'category' => 'other_current_liability'],
            ['code' => '2400', 'name' => 'NSSF Payable', 'type' => 'liability', 'category' => 'other_current_liability'],
            ['code' => '2500', 'name' => 'Accrued Expenses', 'type' => 'liability', 'category' => 'other_current_liability'],
            ['code' => '2600', 'name' => 'Short Term Loan', 'type' => 'liability', 'category' => 'other_current_liability'],
            ['code' => '2700', 'name' => 'Long Term Loan', 'type' => 'liability', 'category' => 'long_term_liability'],

            // Equity (3xxx)
            ['code' => '3000', 'name' => 'Owner\'s Equity', 'type' => 'equity', 'category' => 'equity', 'is_system' => true],
            ['code' => '3100', 'name' => 'Share Capital', 'type' => 'equity', 'category' => 'equity'],
            ['code' => '3200', 'name' => 'Retained Earnings', 'type' => 'equity', 'category' => 'retained_earnings', 'is_system' => true],
            ['code' => '3300', 'name' => 'Owner\'s Drawings', 'type' => 'equity', 'category' => 'equity'],

            // Income (4xxx)
            ['code' => '4000', 'name' => 'Sales Revenue', 'type' => 'income', 'category' => 'income', 'is_system' => true],
            ['code' => '4100', 'name' => 'Service Revenue', 'type' => 'income', 'category' => 'income'],
            ['code' => '4200', 'name' => 'Interest Income', 'type' => 'income', 'category' => 'other_income'],
            ['code' => '4300', 'name' => 'Other Income', 'type' => 'income', 'category' => 'other_income'],
            ['code' => '4400', 'name' => 'Discounts Received', 'type' => 'income', 'category' => 'other_income'],

            // Cost of Goods Sold (5xxx)
            ['code' => '5000', 'name' => 'Cost of Goods Sold', 'type' => 'expense', 'category' => 'cost_of_goods_sold', 'is_system' => true],
            ['code' => '5100', 'name' => 'Purchases', 'type' => 'expense', 'category' => 'cost_of_goods_sold'],
            ['code' => '5200', 'name' => 'Freight In', 'type' => 'expense', 'category' => 'cost_of_goods_sold'],
            ['code' => '5300', 'name' => 'Purchase Discounts', 'type' => 'expense', 'category' => 'cost_of_goods_sold'],

            // Expenses (6xxx)
            ['code' => '6000', 'name' => 'Salaries & Wages', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6100', 'name' => 'Rent Expense', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6200', 'name' => 'Utilities', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6300', 'name' => 'Office Supplies', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6400', 'name' => 'Insurance', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6500', 'name' => 'Depreciation Expense', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6600', 'name' => 'Bank Charges', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6700', 'name' => 'Professional Fees', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6800', 'name' => 'Travel & Transport', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '6900', 'name' => 'Marketing & Advertising', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '7000', 'name' => 'Repairs & Maintenance', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '7100', 'name' => 'Telephone & Internet', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '7200', 'name' => 'Bad Debts', 'type' => 'expense', 'category' => 'expense'],
            ['code' => '7300', 'name' => 'Interest Expense', 'type' => 'expense', 'category' => 'other_expense'],
            ['code' => '7400', 'name' => 'Discounts Given', 'type' => 'expense', 'category' => 'other_expense'],
            ['code' => '7500', 'name' => 'Miscellaneous Expense', 'type' => 'expense', 'category' => 'expense'],
        ];

        foreach ($accounts as $index => $accountData) {
            Account::create([
                'company_id' => $company->id,
                'code' => $accountData['code'],
                'name' => $accountData['name'],
                'type' => $accountData['type'],
                'category' => $accountData['category'],
                'is_system' => $accountData['is_system'] ?? false,
                'is_active' => true,
                'order' => $index + 1,
            ]);
        }
    }

    /**
     * Setup default currencies
     */
    protected function setupDefaultCurrencies(Tenant $tenant): void
    {
        $currencies = [
            ['code' => 'UGX', 'name' => 'Ugandan Shilling', 'symbol' => 'UGX', 'decimal_places' => 0, 'is_active' => true],
            ['code' => 'USD', 'name' => 'US Dollar', 'symbol' => '$', 'decimal_places' => 2, 'is_active' => true],
            ['code' => 'EUR', 'name' => 'Euro', 'symbol' => '€', 'decimal_places' => 2, 'is_active' => true],
            ['code' => 'GBP', 'name' => 'British Pound', 'symbol' => '£', 'decimal_places' => 2, 'is_active' => true],
            ['code' => 'KES', 'name' => 'Kenyan Shilling', 'symbol' => 'KES', 'decimal_places' => 2, 'is_active' => true],
            ['code' => 'TZS', 'name' => 'Tanzanian Shilling', 'symbol' => 'TZS', 'decimal_places' => 0, 'is_active' => true],
            ['code' => 'RWF', 'name' => 'Rwandan Franc', 'symbol' => 'RWF', 'decimal_places' => 0, 'is_active' => true],
        ];

        foreach ($currencies as $currencyData) {
            Currency::firstOrCreate(
                ['code' => $currencyData['code']],
                $currencyData
            );
        }
    }

    /**
     * Add a new user to an existing tenant
     */
    public function addUserToTenant(Tenant $tenant, array $userData): User
    {
        return User::create([
            'tenant_id' => $tenant->id,
            'name' => $userData['name'],
            'email' => $userData['email'],
            'password' => Hash::make($userData['password']),
            'phone' => $userData['phone'] ?? null,
            'role' => $userData['role'] ?? User::ROLE_USER,
            'is_active' => true,
            'email_verified_at' => $userData['verify_email'] ?? false ? now() : null,
        ]);
    }

    /**
     * Add a new company to an existing tenant
     */
    public function addCompanyToTenant(Tenant $tenant, array $companyData): Company
    {
        $company = Company::create([
            'tenant_id' => $tenant->id,
            'name' => $companyData['name'],
            'legal_name' => $companyData['legal_name'] ?? $companyData['name'],
            'email' => $companyData['email'] ?? null,
            'phone' => $companyData['phone'] ?? null,
            'country' => $companyData['country'] ?? $tenant->country,
            'base_currency' => $companyData['base_currency'] ?? $tenant->base_currency,
            'fiscal_year_start' => $companyData['fiscal_year_start'] ?? '01-01',
            'fiscal_year_end' => $companyData['fiscal_year_end'] ?? '12-31',
        ]);

        // Setup default chart of accounts for the new company
        $this->setupDefaultChartOfAccounts($company);

        return $company;
    }

    /**
     * Get tenant statistics
     */
    public function getTenantStatistics(Tenant $tenant): array
    {
        $users = User::where('tenant_id', $tenant->id)->count();
        $companies = Company::where('tenant_id', $tenant->id)->count();

        return [
            'users_count' => $users,
            'companies_count' => $companies,
            'created_at' => $tenant->created_at,
            'plan' => $tenant->plan,
            'status' => $tenant->status,
            'trial_ends_at' => $tenant->trial_ends_at,
            'subscription_ends_at' => $tenant->subscription_ends_at,
            'days_remaining' => $this->getDaysRemaining($tenant),
        ];
    }

    /**
     * Get days remaining in trial or subscription
     */
    protected function getDaysRemaining(Tenant $tenant): ?int
    {
        if ($tenant->plan === 'trial' && $tenant->trial_ends_at) {
            return max(0, now()->diffInDays($tenant->trial_ends_at, false));
        }

        if ($tenant->subscription_ends_at) {
            return max(0, now()->diffInDays($tenant->subscription_ends_at, false));
        }

        return null;
    }
}
