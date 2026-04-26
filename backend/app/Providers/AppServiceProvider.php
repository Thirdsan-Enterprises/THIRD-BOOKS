<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use App\Models\Sales\Invoice;
use App\Models\Sales\Customer;
use App\Models\Purchases\Bill;
use App\Models\Purchases\Vendor;
use App\Models\Sales\Payment;
use App\Models\Accounting\JournalEntry;
use App\Observers\InvoiceObserver;
use App\Observers\CustomerObserver;
use App\Observers\BillObserver;
use App\Observers\VendorObserver;
use App\Observers\PaymentObserver;
use App\Observers\JournalEntryObserver;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Register migration paths for all subdirectories.
        // artisan migrate only globs the top-level migrations/ directory, so
        // subdirectories must be registered explicitly.
        // In single-database mode (TENANCY_MODE=single) all tables live in one
        // database — both central (tenants/users/domains) and tenant-scoped
        // (companies/accounts/invoices etc.) tables are created by artisan migrate.
        // The tenant/ migrations do NOT specify a connection override, so they
        // use the default mysql connection — correct for single-db mode.
        $this->loadMigrationsFrom(database_path('migrations/central'));
        $this->loadMigrationsFrom(database_path('migrations/tenant'));

        // Register model observers for event sourcing
        Invoice::observe(InvoiceObserver::class);
        Customer::observe(CustomerObserver::class);
        Bill::observe(BillObserver::class);
        Vendor::observe(VendorObserver::class);
        Payment::observe(PaymentObserver::class);
        JournalEntry::observe(JournalEntryObserver::class);
    }
}
