<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use App\Models\User;
use App\Models\Tenant\Tenant;
use App\Models\Tenant\Domain;

/**
 * One-shot setup command: creates the MagicBet tenant, company, and
 * admin user (marion@magicbet.ug) if they do not already exist.
 * Safe to re-run — all operations are idempotent.
 */
class SetupMagicBet extends Command
{
    protected $signature = 'magicbet:setup
                            {--password= : Password for marion@magicbet.ug (prompted if omitted)}
                            {--force     : Skip confirmation prompts}';

    protected $description = 'Create MagicBet tenant, company, and marion@magicbet.ug admin user (idempotent)';

    public function handle(): int
    {
        $this->newLine();
        $this->line('╔══════════════════════════════════════════════════════════╗');
        $this->line('║          MagicBet — Initial Setup & User Provision       ║');
        $this->line('╚══════════════════════════════════════════════════════════╝');
        $this->newLine();

        if (!$this->option('force') && !$this->confirm('This will create the MagicBet tenant and admin user. Proceed?', true)) {
            $this->line('Aborted.');
            return 0;
        }

        $password = $this->resolvePassword();

        try {
            DB::beginTransaction();

            $tenant  = $this->ensureTenant();
            $company = $this->ensureCompany($tenant);
            $user    = $this->ensureUser($tenant, $password);

            $this->seedCurrencies($tenant);
            $this->seedChartOfAccounts($tenant, $company);

            DB::commit();
        } catch (\Exception $e) {
            DB::rollBack();
            $this->error('Setup failed: ' . $e->getMessage());
            $this->line($e->getTraceAsString());
            return 1;
        }

        $this->newLine();
        $this->line('══════════════════════════════════════════════════════════');
        $this->line('  <fg=green;options=bold>✓  MagicBet setup complete.</>');
        $this->newLine();
        $this->line('  Login credentials for the desktop / web app:');
        $this->line("  <fg=cyan>  Email   :</> marion@magicbet.ug");
        $this->line("  <fg=cyan>  Password:</> (as entered above)");
        $this->newLine();
        $this->line('  Next steps on the server:');
        $this->line('  <fg=yellow>  php artisan diagnose          (verify everything is clean)</>');
        $this->line('  <fg=yellow>  php artisan queue:work        (start the sync queue worker)</>');
        $this->line('══════════════════════════════════════════════════════════');
        $this->newLine();

        return 0;
    }

    private function ensureTenant(): Tenant
    {
        // Stancl's BaseTenant::create() stores all custom attributes inside
        // the data JSON column, ignoring the real table columns (name,
        // company_name, email…) that our migration defines as NOT NULL.
        // We bypass it with a raw DB insert directly into those columns.
        $existing = DB::table('tenants')
            ->where('email', 'marion@magicbet.ug')
            ->orWhere('name', 'LIKE', '%MagicBet%')
            ->orWhere('name', 'LIKE', '%Magic Bet%')
            ->whereNull('deleted_at')
            ->first();

        if ($existing) {
            $this->info("  ↩  Tenant already exists: {$existing->name} (id={$existing->id})");

            $updates = [];
            if ($existing->status !== 'active') {
                $updates['status'] = 'active';
                $this->line('     <fg=yellow>↳ Status corrected to active.</>');
            }
            if (!$existing->trial_ends_at || strtotime($existing->trial_ends_at) < time()) {
                $updates['trial_ends_at'] = now()->addYear();
                $this->line('     <fg=yellow>↳ Trial extended by 1 year.</>');
            }
            if (!empty($updates)) {
                DB::table('tenants')->where('id', $existing->id)->update(
                    array_merge($updates, ['updated_at' => now()])
                );
            }

            return Tenant::find($existing->id);
        }

        $id  = (string) Str::uuid();
        $now = now();

        DB::table('tenants')->insert([
            'id'                   => $id,
            'name'                 => 'Magic Bet Ltd',
            'company_name'         => 'Magic Bet Ltd',
            'email'                => 'marion@magicbet.ug',
            'phone'                => '',
            'address'              => 'Kampala, Uganda',
            'country'              => 'UG',
            'base_currency'        => 'UGX',
            'fiscal_year_start'    => '07-01',
            'plan'                 => 'trial',
            'trial_ends_at'        => $now->copy()->addYear(),
            'subscription_ends_at' => null,
            'status'               => 'active',
            'settings'             => null,
            'data'                 => null,
            'created_at'           => $now,
            'updated_at'           => $now,
        ]);

        $tenant = Tenant::find($id);
        $this->info("  ✓  Tenant created: {$tenant->name} (id={$tenant->id})");
        return $tenant;
    }

    private function ensureCompany(Tenant $tenant): object
    {
        $existing = DB::table('companies')->where('tenant_id', $tenant->id)->first();
        if ($existing) {
            $this->info("  ↩  Company already exists: {$existing->name} (id={$existing->id})");
            return $existing;
        }

        $now = now();
        $id  = DB::table('companies')->insertGetId([
            'tenant_id'           => $tenant->id,
            'name'                => 'Magic Bet Ltd',
            'legal_name'          => 'Magic Bet Limited',
            'tax_id'              => '',
            'registration_number' => '',
            'email'               => 'marion@magicbet.ug',
            'phone'               => '',
            'address'             => 'Kampala',
            'city'                => 'Kampala',
            'country'             => 'UG',
            'base_currency'       => 'UGX',
            'fiscal_year_start'   => '07-01',
            'fiscal_year_end'     => '06-30',
            'created_at'          => $now,
            'updated_at'          => $now,
        ]);

        $company = DB::table('companies')->find($id);
        $this->info("  ✓  Company created: {$company->name} (id={$company->id})");
        return $company;
    }

    private function ensureUser(Tenant $tenant, string $password): User
    {
        $existing = User::where('email', 'marion@magicbet.ug')->first();

        if ($existing) {
            $this->info("  ↩  User already exists: {$existing->email} (role={$existing->role})");
            $updates = [];
            if ($existing->tenant_id !== $tenant->id) {
                $updates['tenant_id'] = $tenant->id;
                $this->line('     <fg=yellow>↳ tenant_id corrected.</>');
            }
            if (!$existing->is_active) {
                $updates['is_active'] = true;
                $this->line('     <fg=yellow>↳ Account was inactive — activated.</>');
            }
            if ($existing->role !== User::ROLE_ADMIN) {
                $updates['role'] = User::ROLE_ADMIN;
                $this->line('     <fg=yellow>↳ Role elevated to admin.</>');
            }
            if ($this->option('password') || $this->confirm('  Reset the password for marion@magicbet.ug?', false)) {
                $updates['password'] = Hash::make($password);
                $this->line('     <fg=yellow>↳ Password updated.</>');
            }
            if (!empty($updates)) {
                $existing->update($updates);
            }
            return $existing;
        }

        $user = User::create([
            'tenant_id'         => $tenant->id,
            'name'              => 'Marion MagicBet',
            'email'             => 'marion@magicbet.ug',
            'password'          => Hash::make($password),
            'role'              => User::ROLE_ADMIN,
            'is_active'         => true,
            'email_verified_at' => now(),
        ]);

        $this->info("  ✓  User created: {$user->email} (role={$user->role})");
        return $user;
    }

    private function seedCurrencies(Tenant $tenant): void
    {
        $currencies = [
            ['code' => 'UGX', 'name' => 'Ugandan Shilling',  'symbol' => 'UGX', 'decimal_places' => 0],
            ['code' => 'USD', 'name' => 'US Dollar',          'symbol' => '$',   'decimal_places' => 2],
            ['code' => 'KES', 'name' => 'Kenyan Shilling',    'symbol' => 'KES', 'decimal_places' => 2],
            ['code' => 'TZS', 'name' => 'Tanzanian Shilling', 'symbol' => 'TZS', 'decimal_places' => 2],
            ['code' => 'EUR', 'name' => 'Euro',               'symbol' => '€',   'decimal_places' => 2],
        ];

        $seeded = 0;
        foreach ($currencies as $currency) {
            $seeded += DB::table('currencies')->insertOrIgnore(array_merge($currency, [
                'is_active'  => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]));
        }

        $total = DB::table('currencies')->count();
        $seeded > 0
            ? $this->info("  ✓  Currencies seeded ($seeded new, $total total)")
            : $this->info("  ↩  Currencies already exist ($total total)");
    }

    private function seedChartOfAccounts(Tenant $tenant, object $company): void
    {
        $existing = DB::table('accounts')->where('company_id', $company->id)->count();
        if ($existing > 0) {
            $this->info("  ↩  Chart of accounts already seeded ($existing accounts)");
            return;
        }

        $ugxId = DB::table('currencies')->where('code', 'UGX')->value('id');
        if (!$ugxId) {
            $this->warn('UGX currency not found — skipping chart of accounts seeding');
            return;
        }

        $accounts = $this->defaultChartOfAccounts($company->id, $ugxId);
        foreach (array_chunk($accounts, 50) as $chunk) {
            DB::table('accounts')->insertOrIgnore($chunk);
        }
        $this->info('  ✓  Chart of accounts seeded (' . count($accounts) . ' accounts)');
    }

    private function defaultChartOfAccounts(int $companyId, int $currencyId): array
    {
        $now  = now();
        $base = [
            'company_id'      => $companyId,
            'currency_id'     => $currencyId,
            'parent_id'       => null,
            'opening_balance' => 0,
            'current_balance' => 0,
            'is_system'       => true,
            'is_active'       => true,
            'order'           => 0,
            'created_at'      => $now,
            'updated_at'      => $now,
        ];

        return array_map(fn($a) => array_merge($base, $a), [
            ['code' => '100', 'name' => 'Petty Cash',              'type' => 'asset',     'category' => 'cash'],
            ['code' => '101', 'name' => 'ABSA UGX Account',        'type' => 'asset',     'category' => 'bank'],
            ['code' => '102', 'name' => 'MTN Momopay',             'type' => 'asset',     'category' => 'bank'],
            ['code' => '110', 'name' => 'Airtel Money',            'type' => 'asset',     'category' => 'bank'],
            ['code' => '150', 'name' => 'Accounts Receivable',     'type' => 'asset',     'category' => 'accounts_receivable'],
            ['code' => '151', 'name' => 'Deposits — Rent',         'type' => 'asset',     'category' => null],
            ['code' => '152', 'name' => 'Prepayments',             'type' => 'asset',     'category' => null],
            ['code' => '153', 'name' => 'Accrued Income',          'type' => 'asset',     'category' => null],
            ['code' => '160', 'name' => 'Computer Equipment',      'type' => 'asset',     'category' => 'fixed_asset'],
            ['code' => '161', 'name' => 'Furniture & Fittings',    'type' => 'asset',     'category' => 'fixed_asset'],
            ['code' => '162', 'name' => 'Motor Vehicles',          'type' => 'asset',     'category' => 'fixed_asset'],
            ['code' => '170', 'name' => 'Accum. Depreciation',               'type' => 'asset',     'category' => 'fixed_asset'],
            ['code' => '180', 'name' => 'Software Licences',                 'type' => 'asset',     'category' => 'fixed_asset'],
            ['code' => '1700', 'name' => 'Intangible Assets',                'type' => 'asset',     'category' => 'intangible_asset'],
            ['code' => '1710', 'name' => 'Software & Licenses',              'type' => 'asset',     'category' => 'intangible_asset'],
            ['code' => '1720', 'name' => 'Patents & Trademarks',             'type' => 'asset',     'category' => 'intangible_asset'],
            ['code' => '1730', 'name' => 'Goodwill',                         'type' => 'asset',     'category' => 'intangible_asset'],
            ['code' => '1800', 'name' => 'Accumulated Amortization',         'type' => 'asset',     'category' => 'intangible_asset'],
            ['code' => '1810', 'name' => 'Accumulated Amortization - Software', 'type' => 'asset',  'category' => 'intangible_asset'],
            ['code' => '1820', 'name' => 'Accumulated Amortization - Patents',  'type' => 'asset',  'category' => 'intangible_asset'],
            ['code' => '200', 'name' => 'Accounts Payable',        'type' => 'liability', 'category' => 'accounts_payable'],
            ['code' => '201', 'name' => 'VAT Payable',             'type' => 'liability', 'category' => null],
            ['code' => '202', 'name' => 'PAYE Payable',            'type' => 'liability', 'category' => null],
            ['code' => '210', 'name' => 'NSSF Payable',            'type' => 'liability', 'category' => null],
            ['code' => '220', 'name' => 'Accrued Expenses',        'type' => 'liability', 'category' => null],
            ['code' => '230', 'name' => 'Directors Loan',          'type' => 'liability', 'category' => 'long_term_liability'],
            ['code' => '300', 'name' => 'Share Capital',           'type' => 'equity',    'category' => 'equity'],
            ['code' => '310', 'name' => 'Retained Earnings',       'type' => 'equity',    'category' => 'equity'],
            ['code' => '320', 'name' => 'Current Year Profit',     'type' => 'equity',    'category' => 'equity'],
            ['code' => '400', 'name' => 'Betting Revenue',         'type' => 'income',    'category' => 'income'],
            ['code' => '401', 'name' => 'Commission Income',       'type' => 'income',    'category' => 'income'],
            ['code' => '402', 'name' => 'Other Income',            'type' => 'income',    'category' => 'other_income'],
            ['code' => '403', 'name' => 'Interest Income',         'type' => 'income',    'category' => 'other_income'],
            ['code' => '500', 'name' => 'Salaries & Wages',        'type' => 'expense',   'category' => 'expense'],
            ['code' => '501', 'name' => 'Rent Expense',            'type' => 'expense',   'category' => 'expense'],
            ['code' => '502', 'name' => 'Utilities',               'type' => 'expense',   'category' => 'expense'],
            ['code' => '503', 'name' => 'Internet & Telecoms',     'type' => 'expense',   'category' => 'expense'],
            ['code' => '504', 'name' => 'Marketing & Advertising', 'type' => 'expense',   'category' => 'expense'],
            ['code' => '505', 'name' => 'Bank Charges',            'type' => 'expense',   'category' => 'expense'],
            ['code' => '506', 'name' => 'Depreciation Expense',    'type' => 'expense',   'category' => 'expense'],
            ['code' => '507', 'name' => 'Insurance',               'type' => 'expense',   'category' => 'expense'],
            ['code' => '508', 'name' => 'Legal & Professional',    'type' => 'expense',   'category' => 'expense'],
            ['code' => '509', 'name' => 'Stationery & Supplies',   'type' => 'expense',   'category' => 'expense'],
            ['code' => '510', 'name' => 'Transport & Travel',      'type' => 'expense',   'category' => 'expense'],
            ['code' => '511', 'name' => 'Staff Training',          'type' => 'expense',   'category' => 'expense'],
            ['code' => '512', 'name' => 'NSSF Contribution',       'type' => 'expense',   'category' => 'expense'],
            ['code' => '513', 'name' => 'Miscellaneous Expense',   'type' => 'expense',   'category' => 'expense'],
            ['code' => '6910', 'name' => 'Amortization Expense',   'type' => 'expense',   'category' => 'expense'],
        ]);
    }

    private function resolvePassword(): string
    {
        if ($password = $this->option('password')) {
            return $password;
        }

        do {
            $password = $this->secret('  Enter password for marion@magicbet.ug (min 8 chars)');
            if (strlen($password) < 8) {
                $this->error('  Password must be at least 8 characters.');
            }
        } while (strlen($password) < 8);

        $confirm = $this->secret('  Confirm password');
        if ($password !== $confirm) {
            $this->error('  Passwords do not match. Aborting.');
            exit(1);
        }

        return $password;
    }
}
