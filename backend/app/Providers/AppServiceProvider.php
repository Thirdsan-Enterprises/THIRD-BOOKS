<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use App\Models\Sales\Invoice;
use App\Models\Sales\Customer;
use App\Models\Purchases\Bill;
use App\Models\Purchases\Vendor;
use App\Models\Sales\Payment;
use App\Observers\InvoiceObserver;
use App\Observers\CustomerObserver;
use App\Observers\BillObserver;
use App\Observers\VendorObserver;
use App\Observers\PaymentObserver;

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
        // Register model observers for event sourcing
        Invoice::observe(InvoiceObserver::class);
        Customer::observe(CustomerObserver::class);
        Bill::observe(BillObserver::class);
        Vendor::observe(VendorObserver::class);
        Payment::observe(PaymentObserver::class);
    }
}
