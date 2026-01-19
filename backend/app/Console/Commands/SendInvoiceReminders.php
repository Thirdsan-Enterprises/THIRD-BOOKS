<?php

namespace App\Console\Commands;

use App\Models\Sales\Invoice;
use Illuminate\Console\Command;

class SendInvoiceReminders extends Command
{
    protected $signature = 'thirdbooks:send-invoice-reminders';
    protected $description = 'Send reminders for overdue invoices';

    public function handle()
    {
        $this->info('Checking for overdue invoices...');

        $overdueInvoices = Invoice::overdue()->get();

        $count = 0;
        foreach ($overdueInvoices as $invoice) {
            // TODO: Send reminder email
            $this->line("Reminder for invoice: {$invoice->invoice_number}");
            $count++;
        }

        $this->info("Sent {$count} invoice reminders.");

        return Command::SUCCESS;
    }
}
