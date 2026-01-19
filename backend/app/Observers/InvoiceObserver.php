<?php

namespace App\Observers;

use App\Models\Sales\Invoice;
use App\Services\Sync\EventSourceService;

class InvoiceObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Handle the Invoice "created" event.
     */
    public function created(Invoice $invoice): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'invoice',
            aggregateId: $invoice->id,
            eventType: 'invoice.created',
            eventData: [
                'invoice_number' => $invoice->invoice_number,
                'customer_id' => $invoice->customer_id,
                'invoice_date' => $invoice->invoice_date,
                'due_date' => $invoice->due_date,
                'subtotal' => $invoice->subtotal,
                'tax_amount' => $invoice->tax_amount,
                'total' => $invoice->total,
                'status' => $invoice->status,
                'notes' => $invoice->notes,
                'reference_number' => $invoice->reference_number,
            ]
        );
    }

    /**
     * Handle the Invoice "updated" event.
     */
    public function updated(Invoice $invoice): void
    {
        // Only track meaningful changes
        $changes = $invoice->getDirty();

        if (empty($changes)) {
            return;
        }

        // Determine event type based on what changed
        $eventType = 'invoice.updated';

        if (isset($changes['status'])) {
            $eventType = match ($invoice->status) {
                'sent' => 'invoice.sent',
                'paid' => 'invoice.paid',
                'cancelled' => 'invoice.cancelled',
                default => 'invoice.status_changed',
            };
        }

        $this->eventSourceService->createEvent(
            aggregateType: 'invoice',
            aggregateId: $invoice->id,
            eventType: $eventType,
            eventData: array_merge(
                ['changes' => $changes],
                $invoice->only([
                    'invoice_number',
                    'status',
                    'paid_amount',
                    'balance',
                ])
            )
        );
    }

    /**
     * Handle the Invoice "deleted" event.
     */
    public function deleted(Invoice $invoice): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'invoice',
            aggregateId: $invoice->id,
            eventType: 'invoice.deleted',
            eventData: [
                'invoice_number' => $invoice->invoice_number,
                'deleted_at' => now()->toIso8601String(),
            ]
        );
    }
}
