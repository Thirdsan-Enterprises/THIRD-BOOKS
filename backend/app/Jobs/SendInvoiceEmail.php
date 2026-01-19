<?php

namespace App\Jobs;

use App\Models\Sales\Invoice;
use App\Notifications\InvoiceSentNotification;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendInvoiceEmail implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        public Invoice $invoice
    ) {}

    public function handle(): void
    {
        // Send email to customer
        $this->invoice->customer->notify(
            new InvoiceSentNotification($this->invoice)
        );

        // Log activity
        activity()
            ->performedOn($this->invoice)
            ->causedBy($this->invoice->creator)
            ->log('Invoice email sent to customer');
    }
}
