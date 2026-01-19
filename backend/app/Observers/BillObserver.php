<?php

namespace App\Observers;

use App\Models\Purchases\Bill;
use App\Services\Sync\EventSourceService;

class BillObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Handle the Bill "created" event.
     */
    public function created(Bill $bill): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'bill',
            aggregateId: $bill->id,
            eventType: 'bill.created',
            eventData: [
                'bill_number' => $bill->bill_number,
                'vendor_id' => $bill->vendor_id,
                'bill_date' => $bill->bill_date,
                'due_date' => $bill->due_date,
                'subtotal' => $bill->subtotal,
                'tax_amount' => $bill->tax_amount,
                'total' => $bill->total,
                'status' => $bill->status,
                'notes' => $bill->notes,
                'vendor_invoice_number' => $bill->vendor_invoice_number,
            ]
        );
    }

    /**
     * Handle the Bill "updated" event.
     */
    public function updated(Bill $bill): void
    {
        $changes = $bill->getDirty();

        if (empty($changes)) {
            return;
        }

        $eventType = 'bill.updated';

        if (isset($changes['status'])) {
            $eventType = match ($bill->status) {
                'submitted' => 'bill.submitted',
                'approved' => 'bill.approved',
                'rejected' => 'bill.rejected',
                'paid' => 'bill.paid',
                default => 'bill.status_changed',
            };
        }

        $this->eventSourceService->createEvent(
            aggregateType: 'bill',
            aggregateId: $bill->id,
            eventType: $eventType,
            eventData: array_merge(
                ['changes' => $changes],
                $bill->only([
                    'bill_number',
                    'status',
                    'paid_amount',
                    'balance',
                ])
            )
        );
    }

    /**
     * Handle the Bill "deleted" event.
     */
    public function deleted(Bill $bill): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'bill',
            aggregateId: $bill->id,
            eventType: 'bill.deleted',
            eventData: [
                'bill_number' => $bill->bill_number,
                'deleted_at' => now()->toIso8601String(),
            ]
        );
    }
}
