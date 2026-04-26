<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Models\User;
use App\Models\Tenant\Tenant;
use App\Models\Company;

class DiagnoseSystem extends Command
{
    protected $signature = 'diagnose';
    protected $description = 'Full system diagnostic for ThirdBooks / MagicBet — reports every broken link in the chain';

    private int $passCount = 0;
    private int $failCount = 0;
    private int $warnCount = 0;
    private array $failedItems = [];

    public function handle(): int
    {
        $this->newLine();
        $this->line('╔══════════════════════════════════════════════════════════╗');
        $this->line('║    ThirdBooks / MagicBet  —  System Diagnostics          ║');
        $this->line('╚══════════════════════════════════════════════════════════╝');
        $this->newLine();

        $this->checkEnvironment();
        $this->checkDatabase();
        $this->checkAllTables();
        $this->checkMigrations();
        $this->checkUsers();
        $this->checkTenants();
        $this->checkSyncInfrastructure();
        $this->checkStorage();
        $this->checkQueue();
        $this->checkSanctum();
        $this->printSummary();

        return $this->failCount > 0 ? 1 : 0;
    }

    // ─── Section Checks ──────────────────────────────────────────────────────

    private function checkEnvironment(): void
    {
        $this->section('ENVIRONMENT');

        $this->test('PHP version >= 8.2', PHP_VERSION_ID >= 80200, PHP_VERSION);

        $required = ['pdo', 'pdo_mysql', 'mbstring', 'openssl', 'tokenizer', 'xml', 'ctype', 'json', 'bcmath', 'fileinfo'];
        foreach ($required as $ext) {
            $this->test("PHP extension: $ext", extension_loaded($ext));
        }

        $appKey = config('app.key');
        $this->test('APP_KEY is set', !empty($appKey) && str_starts_with($appKey, 'base64:'));
        $this->test('APP_ENV configured', true, config('app.env'));
        $this->test('APP_URL configured', true, config('app.url'));
        $this->test('APP_TIMEZONE', true, config('app.timezone'));
        $this->test('DB_CONNECTION configured', true, config('database.default'));

        $dbName = config('database.connections.' . config('database.default') . '.database');
        $this->test('DB_DATABASE configured', !empty($dbName), $dbName ?: 'NOT SET');
    }

    private function checkDatabase(): void
    {
        $this->section('DATABASE CONNECTION');

        try {
            DB::connection()->getPdo();
            $dbName = DB::connection()->getDatabaseName();
            $version = DB::select('SELECT VERSION() as v')[0]->v ?? 'unknown';
            $this->pass("Connected to: $dbName (MySQL $version)");
        } catch (\Exception $e) {
            $this->fail('Database connection FAILED', $e->getMessage());
            $this->line('');
            $this->line('  <fg=yellow>Fix: check DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD in .env</>');
            // Cannot continue without DB
            $this->printSummary();
            exit(1);
        }
    }

    private function checkAllTables(): void
    {
        $this->section('REQUIRED TABLES');

        $tables = [
            // Core
            'users', 'tenants', 'domains', 'companies', 'currencies', 'exchange_rates',
            // Accounting
            'accounts', 'journal_entries', 'journal_lines', 'general_ledger', 'audit_logs',
            // Sales
            'customers', 'invoices', 'invoice_lines', 'payments', 'credit_notes',
            // Purchases
            'vendors', 'bills', 'bill_lines', 'bill_payments', 'debit_notes',
            // Banking
            'bank_statements', 'bank_statement_lines', 'reconciliation_items',
            // Assets
            'asset_registers', 'depreciation_entries',
            // Sync
            'events', 'sync_queue', 'device_sync_state', 'conflicts', 'sync_logs',
            // Laravel internals
            'personal_access_tokens', 'jobs', 'failed_jobs', 'migrations',
        ];
        // Note: accounts.currency_id (FK) requires currencies to be seeded first

        $missing = [];
        foreach ($tables as $table) {
            if (Schema::hasTable($table)) {
                $count = DB::table($table)->count();
                $this->pass("$table", "$count rows");
            } else {
                $missing[] = $table;
                $this->fail("$table", 'TABLE MISSING — run: php artisan migrate');
            }
        }

        if (!empty($missing)) {
            $this->newLine();
            $this->line('  <fg=yellow>Missing tables mean migrations have not fully run.</>');
            $this->line('  <fg=yellow>Run on the server:  php artisan migrate --force</>');
        }
    }

    private function checkMigrations(): void
    {
        $this->section('MIGRATION STATUS');

        try {
            $ran = DB::table('migrations')->count();
            $this->pass("Migrations recorded in DB", "$ran total");
        } catch (\Exception $e) {
            $this->fail('Cannot read migrations table', $e->getMessage());
        }
    }

    private function checkUsers(): void
    {
        $this->section('USERS');

        try {
            $total = User::count();
            $this->pass("Total users in DB", "$total");

            // Super admin
            $superAdmin = User::whereNull('tenant_id')
                ->where('role', 'super_admin')
                ->first();

            if ($superAdmin) {
                $this->pass('Super Admin exists', $superAdmin->email);
            } else {
                $this->fail('Super Admin missing', 'Run: php artisan db:seed --class=SuperAdminSeeder');
            }

            // MagicBet admin user
            $marion = User::where('email', 'marion@magicbet.ug')->first();
            if ($marion) {
                $status = $marion->is_active ? 'active' : 'INACTIVE';
                $this->pass('marion@magicbet.ug exists', "role={$marion->role}, status=$status, tenant=" . ($marion->tenant_id ?? 'NULL'));
            } else {
                $this->warn('marion@magicbet.ug NOT FOUND', 'Run: php artisan magicbet:setup');
            }
        } catch (\Exception $e) {
            $this->fail('Cannot query users table', $e->getMessage());
        }
    }

    private function checkTenants(): void
    {
        $this->section('TENANTS & COMPANIES');

        try {
            $tenantCount = DB::table('tenants')->count();
            $this->test('At least one tenant exists', $tenantCount > 0, "$tenantCount tenants");

            $magicbet = DB::table('tenants')
                ->where('name', 'LIKE', '%MagicBet%')
                ->orWhere('name', 'LIKE', '%Magic Bet%')
                ->orWhere('email', 'LIKE', '%magicbet.ug%')
                ->first();

            if ($magicbet) {
                $this->pass('MagicBet tenant exists', "id={$magicbet->id}, status={$magicbet->status}, plan={$magicbet->plan}");

                // Check canAccess equivalent
                $canAccess = $magicbet->status === 'active' && (
                    (!$magicbet->subscription_ends_at) ||
                    (strtotime($magicbet->subscription_ends_at) > time()) ||
                    (!$magicbet->trial_ends_at) ||
                    (strtotime($magicbet->trial_ends_at) > time())
                );
                $this->test('MagicBet tenant can access system', $canAccess,
                    $canAccess ? 'access granted' : 'BLOCKED — trial/subscription expired');
            } else {
                $this->warn('MagicBet tenant NOT FOUND', 'Run: php artisan magicbet:setup');
            }

            $companyCount = DB::table('companies')->count();
            $this->test('At least one company exists', $companyCount > 0, "$companyCount companies");
        } catch (\Exception $e) {
            $this->fail('Cannot query tenants', $e->getMessage());
        }
    }

    private function checkSyncInfrastructure(): void
    {
        $this->section('SYNC INFRASTRUCTURE');

        $syncTables = ['events', 'sync_queue', 'device_sync_state', 'conflicts', 'sync_logs'];
        foreach ($syncTables as $table) {
            try {
                $count = DB::table($table)->count();
                $this->pass("$table accessible", "$count records");
            } catch (\Exception $e) {
                $this->fail("$table not accessible", $e->getMessage());
            }
        }

        // Check if any sync has ever happened
        try {
            $deviceCount = DB::table('device_sync_state')->count();
            if ($deviceCount === 0) {
                $this->warn('No devices have ever synced', 'Devices have not registered with the server yet');
            } else {
                $latest = DB::table('device_sync_state')->orderByDesc('last_sync_at')->first();
                $this->pass("Last sync", "device={$latest->device_id}, seq={$latest->last_synced_sequence}, at={$latest->last_sync_at}");
            }
        } catch (\Exception $e) {
            $this->warn('Cannot read device sync state', $e->getMessage());
        }

        // Check failed_jobs (failed sync events)
        try {
            $failed = DB::table('failed_jobs')->count();
            $this->test('No failed queue jobs', $failed === 0, $failed > 0 ? "$failed FAILED JOBS — run: php artisan queue:retry all" : 'clean');
        } catch (\Exception $e) {
            $this->warn('Cannot read failed_jobs', $e->getMessage());
        }
    }

    private function checkStorage(): void
    {
        $this->section('STORAGE & FILE PERMISSIONS');

        $paths = [
            storage_path('logs')                => 'storage/logs writable',
            storage_path('framework/cache')     => 'storage/framework/cache writable',
            storage_path('framework/sessions')  => 'storage/framework/sessions writable',
            storage_path('framework/views')     => 'storage/framework/views writable',
            base_path('bootstrap/cache')        => 'bootstrap/cache writable',
        ];

        foreach ($paths as $path => $label) {
            if (!is_dir($path)) {
                @mkdir($path, 0755, true);
            }
            $this->test($label, is_writable($path));
        }
    }

    private function checkQueue(): void
    {
        $this->section('QUEUE & JOBS');

        $driver = config('queue.default');
        $this->test('Queue driver set', !empty($driver), $driver);

        if ($driver === 'redis') {
            try {
                $redis = app('redis')->ping();
                $this->pass('Redis reachable', 'PONG received');
            } catch (\Exception $e) {
                $this->fail('Redis NOT reachable', $e->getMessage());
            }
        }

        try {
            $pending = DB::table('jobs')->count();
            $this->test('Pending jobs', true, "$pending pending");
        } catch (\Exception $e) {
            $this->warn('Cannot read jobs table', $e->getMessage());
        }
    }

    private function checkSanctum(): void
    {
        $this->section('SANCTUM / API AUTH');

        try {
            $tokenCount = DB::table('personal_access_tokens')->count();
            $this->pass('personal_access_tokens table accessible', "$tokenCount tokens issued");

            $statefulDomains = config('sanctum.stateful');
            $this->test('SANCTUM_STATEFUL_DOMAINS set', !empty($statefulDomains),
                is_array($statefulDomains) ? implode(', ', $statefulDomains) : $statefulDomains);
        } catch (\Exception $e) {
            $this->fail('Sanctum check failed', $e->getMessage());
        }
    }

    // ─── Output Helpers ───────────────────────────────────────────────────────

    private function section(string $title): void
    {
        $bar = str_repeat('─', max(0, 54 - strlen($title)));
        $this->newLine();
        $this->line("<fg=cyan;options=bold>── $title $bar</>");
    }

    private function test(string $label, bool $ok, string $detail = ''): void
    {
        if ($ok) {
            $this->pass($label, $detail);
        } else {
            $this->fail($label, $detail);
        }
    }

    private function pass(string $label, string $detail = ''): void
    {
        $this->passCount++;
        $suffix = $detail ? "  <fg=gray>($detail)</>" : '';
        $this->line("  <fg=green>✓</>  $label$suffix");
    }

    private function fail(string $label, string $detail = ''): void
    {
        $this->failCount++;
        $this->failedItems[] = $label;
        $suffix = $detail ? "  <fg=red>→ $detail</>" : '';
        $this->line("  <fg=red>✗</>  <fg=red>$label</>$suffix");
    }

    private function warn(string $label, string $detail = ''): void
    {
        $this->warnCount++;
        $suffix = $detail ? "  <fg=yellow>→ $detail</>" : '';
        $this->line("  <fg=yellow>⚠</>  $label$suffix");
    }

    private function printSummary(): void
    {
        $this->newLine();
        $this->line('══════════════════════════════════════════════════════════');
        $this->line("  Results:  <fg=green>PASS {$this->passCount}</>   <fg=red>FAIL {$this->failCount}</>   <fg=yellow>WARN {$this->warnCount}</>");
        $this->newLine();

        if ($this->failCount === 0 && $this->warnCount === 0) {
            $this->line('  <fg=green;options=bold>✓  All checks passed. System is healthy and ready to sync.</>');
        } elseif ($this->failCount === 0) {
            $this->line('  <fg=yellow;options=bold>⚠  No failures, but warnings need attention (see above).</>');
            $this->line('  <fg=yellow>   Run: php artisan magicbet:setup  to resolve user/tenant warnings.</>');
        } else {
            $this->line('  <fg=red;options=bold>✗  FAILURES DETECTED — data cannot sync until these are fixed:</>');
            $this->newLine();
            foreach ($this->failedItems as $item) {
                $this->line("    <fg=red>•</>  $item");
            }
            $this->newLine();
            $this->line('  <fg=yellow>Common fixes:</>');
            $this->line('  <fg=yellow>   php artisan migrate --force          (missing tables)</>');
            $this->line('  <fg=yellow>   php artisan key:generate             (missing APP_KEY)</>');
            $this->line('  <fg=yellow>   chmod -R 775 storage bootstrap/cache (permission issues)</>');
            $this->line('  <fg=yellow>   php artisan magicbet:setup           (user / tenant issues)</>');
        }

        $this->line('══════════════════════════════════════════════════════════');
        $this->newLine();
    }
}
