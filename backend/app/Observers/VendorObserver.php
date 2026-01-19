<?php

namespace App\Observers;

use App\Models\Purchases\Vendor;
use App\Services\Sync\EventSourceService;

class VendorObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Handle the Vendor "created" event.
     */
    public function created(Vendor $vendor): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'vendor',
            aggregateId: $vendor->id,
            eventType: 'vendor.created',
            eventData: [
                'name' => $vendor->name,
                'email' => $vendor->email,
                'phone' => $vendor->phone,
                'address' => $vendor->address,
                'city' => $vendor->city,
                'state' => $vendor->state,
                'postal_code' => $vendor->postal_code,
                'country' => $vendor->country,
                'tax_number' => $vendor->tax_number,
                'currency' => $vendor->currency,
                'payment_terms' => $vendor->payment_terms,
                'notes' => $vendor->notes,
            ]
        );
    }

    /**
     * Handle the Vendor "updated" event.
     */
    public function updated(Vendor $vendor): void
    {
        $changes = $vendor->getDirty();

        if (empty($changes)) {
            return;
        }

        $this->eventSourceService->createEvent(
            aggregateType: 'vendor',
            aggregateId: $vendor->id,
            eventType: 'vendor.updated',
            eventData: array_merge(
                ['changes' => $changes],
                $vendor->only([
                    'name',
                    'email',
                    'phone',
                    'address',
                ])
            )
        );
    }

    /**
     * Handle the Vendor "deleted" event.
     */
    public function deleted(Vendor $vendor): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'vendor',
            aggregateId: $vendor->id,
            eventType: 'vendor.deleted',
            eventData: [
                'name' => $vendor->name,
                'deleted_at' => now()->toIso8601String(),
            ]
        );
    }
}
