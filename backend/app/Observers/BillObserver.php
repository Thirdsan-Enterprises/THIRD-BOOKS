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
     *
     * BillController::store() explicitly emits a full bill.created event (with
     * company_id, correct date field, and eager-loaded lines) AFTER its DB
     * transaction commits.  Emitting a second, incomplete event here would
     * produce a duplicate with wrong field names (bill_date vs date) and no
     * company_id, which corrupts materialization on other devices.
     *
     * For bills created outside the REST controller (e.g. during sync
     * materialization) the $materializing guard in createEvent() already
     * suppresses this path, so no event is ever double-emitted.
     */
    public function created(Bill $bill): void
    {
        // Intentionally empty: BillController emits the authoritative event
        // after commit with full data (company_id, lines, correct field names).
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
